import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../provider/diff_provider.dart';

/// Page for comparing two text blocks.
class DiffPage extends ConsumerStatefulWidget {
  const DiffPage({super.key});

  @override
  ConsumerState<DiffPage> createState() => _DiffPageState();
}

class _DiffPageState extends ConsumerState<DiffPage> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: ref.read(diffLeftProvider));
    _rightController = TextEditingController(text: ref.read(diffRightProvider));
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
    super.dispose();
  }

  void _clear() {
    _leftController.clear();
    _rightController.clear();
    ref.read(diffResultProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final diffs = ref.watch(diffResultProvider);
    final summary = _diffStats(diffs);
    return Scaffold(
      appBar: AppBar(title: const Text('Diff Checker')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final left = _Editor(label: 'Text A', controller: _leftController);
          final right = _Editor(label: 'Text B', controller: _rightController);
          final result = _DiffResultPanel(
            diffs: diffs,
            summary: summary,
            onCopySummary: diffs.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: _summaryFromStats(summary)),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diff summary copied')),
                    );
                  },
          );
          return Padding(
            padding: AppSpacing.page(context),
            child: Column(
              children: [
                Expanded(
                  flex: isWide ? 5 : 6,
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: right),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: left),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(child: right),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      onPressed: () => computeDiff(ref),
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Compare'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.backspace_outlined),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(flex: isWide ? 4 : 5, child: result),
              ],
            ),
          );
        },
      ),
    );
  }

  _DiffStats _diffStats(List<dmp.Diff> diffs) {
    final added = diffs
        .where((diff) => diff.operation == dmp.DIFF_INSERT)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    final removed = diffs
        .where((diff) => diff.operation == dmp.DIFF_DELETE)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    final unchanged = diffs
        .where((diff) => diff.operation == dmp.DIFF_EQUAL)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    return _DiffStats(
      added: added,
      removed: removed,
      unchanged: unchanged,
      changed: added + removed,
    );
  }

  String _summaryFromStats(_DiffStats stats) {
    return 'Added: ${stats.added} characters\n'
        'Removed: ${stats.removed} characters\n'
        'Changed: ${stats.changed} characters\n'
        'Unchanged: ${stats.unchanged} characters';
  }
}

class _DiffStats {
  final int added;
  final int removed;
  final int changed;
  final int unchanged;

  const _DiffStats({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unchanged,
  });
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
  final _DiffStats summary;
  final VoidCallback? onCopySummary;

  const _DiffResultPanel({
    required this.diffs,
    required this.summary,
    required this.onCopySummary,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(label: 'Added ${summary.added}'),
                      AppBadge(label: 'Removed ${summary.removed}'),
                      AppBadge(label: 'Changed ${summary.changed}'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy diff summary',
                  onPressed: onCopySummary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: diffs.isEmpty
                ? const AppEmptyState(
                    icon: Icons.difference,
                    title: 'Differences will appear here',
                    message: 'Paste two text blocks and compare them.',
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
      if (diff.operation == dmp.DIFF_INSERT) {
        bgColor = AppColors.success.withValues(alpha: 0.20);
      } else if (diff.operation == dmp.DIFF_DELETE) {
        bgColor = AppColors.destructive.withValues(alpha: 0.20);
      }
      spans.add(
        TextSpan(
          text: diff.text,
          style: TextStyle(backgroundColor: bgColor),
        ),
      );
    }
    return SelectableText.rich(
      TextSpan(
        style: AppTypography.mono(context),
        children: spans,
      ),
    );
  }
}
