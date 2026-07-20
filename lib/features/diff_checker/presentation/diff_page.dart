import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_responsive_scaffold.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/security/data_redactor.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/utils/diff_utils.dart';
import '../../../core/utils/secret_utils.dart';
import '../provider/diff_provider.dart';
import '../models/diff_models.dart';
import '../provider/github_service.dart';
import 'widgets/diff_history_panel.dart';

class DiffPage extends ConsumerStatefulWidget {
  const DiffPage({super.key});

  @override
  ConsumerState<DiffPage> createState() => _DiffPageState();
}

class _DiffPageState extends ConsumerState<DiffPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  late final TextEditingController _githubUrlController;
  late final TabController _tabController;

  final List<DiffSession> _history = [];
  int _diffGeneration = 0;
  bool _diffRunning = false;
  String? _diffError;

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: ref.read(diffLeftProvider));
    _rightController = TextEditingController(text: ref.read(diffRightProvider));
    _githubUrlController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);

    _leftController.addListener(() {
      ref.read(diffLeftProvider.notifier).state = _leftController.text;
    });
    _rightController.addListener(() {
      ref.read(diffRightProvider.notifier).state = _rightController.text;
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _githubUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _clear() {
    _leftController.clear();
    _rightController.clear();
    ref.read(diffResultProvider.notifier).state = [];
    ref.read(diffSummaryProvider.notifier).state = null;
  }

  Future<void> _pickFile(bool isLeft) async {
    try {
      final doc = await ExternalFileService.pickDeveloperFile();
      if (doc != null) {
        if (SecretUtils.containsSecret(doc.content, fileName: doc.name)) {
          if (!mounted) return;
          final proceed = await _showSecretWarning(context);
          if (proceed != true) return;
        }

        if (isLeft) {
          _leftController.text = doc.content;
          ref.read(diffSourceLeftProvider.notifier).state = DiffSource.file;
        } else {
          _rightController.text = doc.content;
          ref.read(diffSourceRightProvider.notifier).state = DiffSource.file;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool?> _showSecretWarning(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensitive Information Detected'),
        content: const Text(
          'This file appears to contain secrets (like API keys or tokens). '
          'DevDesk processes everything locally, but be careful when sharing or exporting diff reports.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Text', icon: Icon(Icons.text_fields)),
            Tab(text: 'Files', icon: Icon(Icons.file_copy)),
            Tab(text: 'GitHub', icon: Icon(Icons.cloud_download)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTextTab(),
              _buildFilesTab(),
              _buildGitHubTab(),
              DiffHistoryPanel(
                sessions: _history,
                onSelect: (session) {
                  _leftController.text = session.left.content;
                  _rightController.text = session.right.content;
                  ref.read(diffOptionsProvider.notifier).state =
                      session.options;
                  _runDiff(saveHistory: false);
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
        ),
      ],
    );

    return AppResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Diff Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showOptions,
            tooltip: 'Diff Options',
          ),
        ],
      ),
      compactBody: body,
      expandedBody: body,
    );
  }

  Widget _buildTextTab() {
    final diffs = ref.watch(diffResultProvider);
    final summary = ref.watch(diffSummaryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.medium;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Expanded(
                flex: isWide ? 5 : 6,
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                              child: _Editor(
                                  label: 'Source A',
                                  controller: _leftController)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: _Editor(
                                  label: 'Source B',
                                  controller: _rightController)),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                              child: _Editor(
                                  label: 'Source A',
                                  controller: _leftController)),
                          const SizedBox(height: AppSpacing.md),
                          Expanded(
                              child: _Editor(
                                  label: 'Source B',
                                  controller: _rightController)),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: _diffRunning ? null : _runDiff,
                    icon: _diffRunning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compare_arrows),
                    label: Text(_diffRunning ? 'Comparing…' : 'Compare'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Clear'),
                  ),
                  if (diffs.isNotEmpty)
                    PopupMenuButton<String>(
                      onSelected: _handleExport,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'txt', child: Text('Export as Text')),
                        const PopupMenuItem(
                            value: 'md', child: Text('Export as Markdown')),
                        const PopupMenuItem(
                            value: 'patch', child: Text('Copy Patch')),
                      ],
                      child: const OutlinedButton(
                        onPressed: null,
                        child: Text('Export'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _diffError ?? (_diffRunning ? 'Comparison in progress' : ''),
                  style: _diffError == null
                      ? Theme.of(context).textTheme.bodySmall
                      : TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              if (_diffError != null || _diffRunning)
                const SizedBox(height: AppSpacing.sm),
              Expanded(
                flex: isWide ? 4 : 5,
                child: _DiffResultPanel(
                  diffs: diffs,
                  summary: summary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_copy, size: 64, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Local File Comparison',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Select two supported text, code, Markdown, or JSON files and compare their contents locally.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _pickFile(true),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick File A'),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => _pickFile(false),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick File B'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGitHubTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, size: 64, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('GitHub Integration',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _githubUrlController,
              decoration: const InputDecoration(
                labelText: 'Public GitHub file URL',
                hintText: 'https://github.com/owner/repo/blob/main/file.txt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () async {
                final ref = GitHubService.parseUrl(_githubUrlController.text);
                if (ref == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid GitHub URL')));
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final content = await GitHubService.fetchFileContent(ref);
                  if (!mounted) return;
                  Navigator.pop(context); // Close loading

                  if (content != null) {
                    _rightController.text = content;
                    this.ref.read(diffSourceRightProvider.notifier).state =
                        DiffSource.github;
                    _tabController.animateTo(0);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('File fetched from GitHub')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'The public file could not be fetched. Check the URL, branch, path, and network access.')));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'GitHub fetch failed safely: ${DataRedactor.safeError(e)}',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Fetch & Compare'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentOptions = ref.watch(diffOptionsProvider);
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Diff Options',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  title: const Text('Ignore Whitespace'),
                  value: currentOptions.ignoreWhitespace,
                  onChanged: (val) => ref
                      .read(diffOptionsProvider.notifier)
                      .state = DiffOptions(
                    ignoreWhitespace: val,
                    ignoreCase: currentOptions.ignoreCase,
                    ignoreEmptyLines: currentOptions.ignoreEmptyLines,
                    jsonKeyOrderIgnore: currentOptions.jsonKeyOrderIgnore,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Ignore Case'),
                  value: currentOptions.ignoreCase,
                  onChanged: (val) => ref
                      .read(diffOptionsProvider.notifier)
                      .state = DiffOptions(
                    ignoreWhitespace: currentOptions.ignoreWhitespace,
                    ignoreCase: val,
                    ignoreEmptyLines: currentOptions.ignoreEmptyLines,
                    jsonKeyOrderIgnore: currentOptions.jsonKeyOrderIgnore,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Normalize JSON Key Order'),
                  value: currentOptions.jsonKeyOrderIgnore,
                  onChanged: (val) => ref
                      .read(diffOptionsProvider.notifier)
                      .state = DiffOptions(
                    ignoreWhitespace: currentOptions.ignoreWhitespace,
                    ignoreCase: currentOptions.ignoreCase,
                    ignoreEmptyLines: currentOptions.ignoreEmptyLines,
                    jsonKeyOrderIgnore: val,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runDiff({bool saveHistory = true}) async {
    final operationId = ++_diffGeneration;
    setState(() {
      _diffRunning = true;
      _diffError = null;
    });
    try {
      final options = ref.read(diffOptionsProvider);
      final diffs = await computeDiffInWorker(
        left: _leftController.text,
        right: _rightController.text,
        options: options,
      );
      if (!mounted || operationId != _diffGeneration) return;
      ref.read(diffResultProvider.notifier).state = diffs;
      ref.read(diffSummaryProvider.notifier).state =
          DiffUtils.calculateSummary(diffs);
      if (saveHistory) _saveToHistory();
    } catch (error) {
      if (!mounted || operationId != _diffGeneration) return;
      setState(() {
        _diffError = DataRedactor.safeError(error);
      });
    } finally {
      if (mounted && operationId == _diffGeneration) {
        setState(() => _diffRunning = false);
      }
    }
  }

  void _saveToHistory() {
    final summary = ref.read(diffSummaryProvider);
    if (summary == null) return;

    final session = DiffSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Comparison at ${_formatTime(DateTime.now())}',
      left: DiffContent(
        content: DataRedactor.redactText(_leftController.text),
        source: ref.read(diffSourceLeftProvider),
      ),
      right: DiffContent(
        content: DataRedactor.redactText(_rightController.text),
        source: ref.read(diffSourceRightProvider),
      ),
      options: ref.read(diffOptionsProvider),
      createdAt: DateTime.now(),
      summary: summary,
    );

    setState(() {
      _history.insert(0, session);
      if (_history.length > 20) {
        _history.removeRange(20, _history.length);
      }
    });
  }

  String _formatTime(DateTime date) =>
      '${date.hour}:${date.minute}:${date.second}';

  Future<void> _handleExport(String format) async {
    final left = DataRedactor.redactText(_leftController.text);
    final right = DataRedactor.redactText(_rightController.text);
    final patch = DiffUtils.generatePatch(left, right);
    if (format == 'patch') {
      await SafeClipboard.copy(patch, forceRedaction: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Redacted patch copied to clipboard')),
      );
      return;
    }
    final markdown = format == 'md';
    final content = markdown
        ? '# DevDesk diff report\n\n## Source A\n\n```text\n$left\n```\n\n## Source B\n\n```text\n$right\n```\n\n## Unified patch\n\n```diff\n$patch\n```\n'
        : 'DEVDESK DIFF REPORT\n\nSOURCE A\n$left\n\nSOURCE B\n$right\n\nUNIFIED PATCH\n$patch\n';
    final path = await ExternalFileService.saveTextAs(
      suggestedName: markdown ? 'devdesk-diff.md' : 'devdesk-diff.txt',
      content: content,
      allowedExtensions: [markdown ? 'md' : 'txt'],
      dialogTitle: 'Export redacted diff report',
    );
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redacted diff report exported')),
    );
  }
}

class _Editor extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _Editor({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              minLines: null,
              maxLines: null,
              style: AppTypography.mono(context),
              decoration: InputDecoration(
                hintText: 'Paste $label here',
                alignLabelWithHint: true,
                fillColor: AppColors.codeBackground(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffResultPanel extends StatelessWidget {
  final List<dmp.Diff> diffs;
  final DiffSummary? summary;

  const _DiffResultPanel({
    required this.diffs,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppBadge(
                      label: 'Added ${summary!.added}', color: Colors.green),
                  AppBadge(
                      label: 'Removed ${summary!.removed}', color: Colors.red),
                  AppBadge(
                      label: 'Blocks ${summary!.changedBlocks}',
                      color: Colors.blue),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: diffs.isEmpty
                ? const AppEmptyState(
                    icon: Icons.difference,
                    title: 'No differences',
                    message: 'Compare two sources to see the result.',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _DiffText(diffs: diffs),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiffText extends StatelessWidget {
  final List<dmp.Diff> diffs;

  const _DiffText({required this.diffs});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    for (final diff in diffs) {
      Color? bgColor;
      Color? textColor;
      if (diff.operation == dmp.DIFF_INSERT) {
        bgColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[800];
      } else if (diff.operation == dmp.DIFF_DELETE) {
        bgColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red[800];
      }
      spans.add(
        TextSpan(
          text: diff.text,
          style: TextStyle(backgroundColor: bgColor, color: textColor),
        ),
      );
    }
    final semanticBuffer = StringBuffer('Diff result. ');
    const semanticLimit = 20000;
    for (final diff in diffs) {
      final operation = switch (diff.operation) {
        dmp.DIFF_INSERT => 'Inserted',
        dmp.DIFF_DELETE => 'Deleted',
        _ => 'Unchanged',
      };
      semanticBuffer
        ..write(operation)
        ..write(': ')
        ..write(diff.text)
        ..write('. ');
      if (semanticBuffer.length >= semanticLimit) {
        semanticBuffer
            .write('Remaining diff omitted from screen reader preview.');
        break;
      }
    }
    return Semantics(
      container: true,
      readOnly: true,
      label: semanticBuffer.toString(),
      child: ExcludeSemantics(
        child: SelectableText.rich(
          TextSpan(
            style: AppTypography.mono(context),
            children: spans,
          ),
        ),
      ),
    );
  }
}
