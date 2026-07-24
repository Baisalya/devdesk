import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_editor_panel.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_tool_app_bar.dart';
import '../provider/json_provider.dart';

/// Page for viewing, validating and formatting JSON.
class JsonPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const JsonPage({super.key, this.initialDocument});

  @override
  ConsumerState<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends ConsumerState<JsonPage> {
  late final TextEditingController _inputController;
  ExternalFileDocument? _externalDocument;

  @override
  void initState() {
    super.initState();
    _externalDocument = widget.initialDocument;
    final String initialText =
        widget.initialDocument?.content ?? ref.read(jsonInputProvider);
    _inputController = TextEditingController(text: initialText);
    _inputController.addListener(() {
      ref.read(jsonInputProvider.notifier).state = _inputController.text;
    });
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(jsonInputProvider.notifier).state = initialText;
        formatJson(ref);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _clear() {
    _inputController.clear();
    ref.read(jsonOutputProvider.notifier).state = null;
    setState(() {
      _externalDocument = null;
    });
  }

  Future<void> _saveJson({required bool minified}) async {
    try {
      final input = _inputController.text;
      final content =
          minified ? JsonUtils.minify(input) : JsonUtils.prettyPrint(input);
      final path = await ExternalFileService.saveTextAs(
        suggestedName: _externalDocument?.name ?? 'formatted.json',
        content: content,
        allowedExtensions: const ['json'],
        dialogTitle: minified ? 'Save minified JSON' : 'Save formatted JSON',
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(minified ? 'Minified JSON saved' : 'Formatted JSON saved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(jsonOutputProvider);
    dynamic treeData;
    if (output != null && !output.startsWith('Invalid')) {
      try {
        treeData = JsonUtils.parseJson(output);
      } catch (_) {
        treeData = null;
      }
    }

    return Scaffold(
      appBar: AppToolAppBar(
        route: '/json',
        title: _externalDocument?.name,
      ),
      body: Column(
        children: [
          if (_externalDocument != null)
            _JsonSourceBanner(document: _externalDocument!),
          _JsonToolbar(
            output: output,
            onFormat: () => formatJson(ref),
            onMinify: () => minifyJson(ref),
            onClear: _clear,
            onSaveFormatted: () => _saveJson(minified: false),
            onSaveMinified: () => _saveJson(minified: true),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= AppBreakpoints.medium;
                final input = _InputEditor(controller: _inputController);
                final outputView =
                    _OutputView(output: output, treeData: treeData);
                return Padding(
                  padding:
                      AppSpacing.page(context).copyWith(top: AppSpacing.md),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(child: input),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: outputView),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: input),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(child: outputView),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonToolbar extends StatelessWidget {
  final String? output;
  final VoidCallback onFormat;
  final VoidCallback onMinify;
  final VoidCallback onClear;
  final VoidCallback onSaveFormatted;
  final VoidCallback onSaveMinified;

  const _JsonToolbar({
    required this.output,
    required this.onFormat,
    required this.onMinify,
    required this.onClear,
    required this.onSaveFormatted,
    required this.onSaveMinified,
  });

  @override
  Widget build(BuildContext context) {
    final copyValue = output;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          FilledButton.icon(
            onPressed: onFormat,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Format'),
          ),
          OutlinedButton.icon(
            onPressed: onMinify,
            icon: const Icon(Icons.compress),
            label: const Text('Minify'),
          ),
          OutlinedButton.icon(
            onPressed: copyValue == null
                ? null
                : () async {
                    final redacted = await SafeClipboard.copy(
                      copyValue,
                      content: SafeClipboardContent.json,
                      forceRedaction: true,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(redacted
                            ? 'Copied with secrets redacted'
                            : 'Copied to clipboard'),
                      ),
                    );
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Clear'),
          ),
          OutlinedButton.icon(
            onPressed: onSaveFormatted,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save formatted'),
          ),
          OutlinedButton.icon(
            onPressed: onSaveMinified,
            icon: const Icon(Icons.save_as),
            label: const Text('Save minified'),
          ),
        ],
      ),
    );
  }
}

class _JsonSourceBanner extends StatelessWidget {
  final ExternalFileDocument document;

  const _JsonSourceBanner({required this.document});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.data_object, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'External JSON: ${document.sourceLabel}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputEditor extends StatelessWidget {
  final TextEditingController controller;

  const _InputEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppEditorPanel(
      title: 'Input',
      subtitle: 'Paste raw JSON',
      child: TextField(
        controller: controller,
        expands: true,
        minLines: null,
        maxLines: null,
        style: AppTypography.mono(context),
        decoration: InputDecoration(
          hintText: 'Paste JSON here...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: AppColors.codeBackground(context),
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}

class _OutputView extends StatelessWidget {
  final String? output;
  final dynamic treeData;

  const _OutputView({required this.output, required this.treeData});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (output == null) {
      child = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Output will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    } else if (output!.startsWith('Invalid')) {
      child = Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: SelectableText(
            output!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else {
      child = DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Raw'),
                Tab(text: 'Tree'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Container(
                    color: AppColors.codeBackground(context),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          output!,
                          style: AppTypography.mono(context),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: treeData == null
                        ? const AppErrorState(message: 'Invalid JSON')
                        : JsonTreeView(data: treeData),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return AppEditorPanel(
      title: 'Result',
      subtitle: output == null ? 'Formatted output and tree view' : 'Ready',
      child: child,
    );
  }
}

/// A widget that recursively displays a JSON object as expandable tiles. It
/// supports Maps and Lists. Primitive values are shown as text.
class JsonTreeView extends StatelessWidget {
  final dynamic data;
  final String? keyName;

  const JsonTreeView({super.key, required this.data, this.keyName});

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      final map = data as Map;
      if (map.isEmpty) return _buildLeaf(context, keyName ?? '{}', '{}');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: map.entries.map((entry) {
          return _buildNode(context, entry.key.toString(), entry.value);
        }).toList(),
      );
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) return _buildLeaf(context, keyName ?? '[]', '[]');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < list.length; i++)
            _buildNode(context, '[$i]', list[i]),
        ],
      );
    }
    return _buildLeaf(context, keyName ?? 'value', data);
  }

  Widget _buildNode(BuildContext context, String key, dynamic value) {
    if (value is Map || value is List) {
      final itemCount = value is Map ? value.length : (value as List).length;
      final kind = value is Map ? 'object' : 'array';
      return Semantics(
        container: true,
        label: '$key, expandable $kind with $itemCount items',
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: ExcludeSemantics(
            child: Text(key, style: AppTypography.mono(context)),
          ),
          children: [JsonTreeView(data: value)],
        ),
      );
    }
    return _buildLeaf(context, key, value);
  }

  Widget _buildLeaf(BuildContext context, String key, dynamic value) {
    final displayValue = value.toString();
    final semanticValue = displayValue.length <= 500
        ? displayValue
        : '${displayValue.substring(0, 500)}, value truncated for screen reader';
    return Semantics(
      container: true,
      readOnly: true,
      label: '$key: $semanticValue',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$key: ',
                style: AppTypography.mono(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(displayValue, style: AppTypography.mono(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
