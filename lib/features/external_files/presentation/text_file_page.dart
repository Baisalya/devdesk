import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/platform/window_close_guard.dart';
import '../../../core/security/data_redactor.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/utils/secret_utils.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../snippets/models/snippet.dart';
import '../../snippets/provider/snippets_provider.dart';

class TextFilePage extends ConsumerStatefulWidget {
  final ExternalFileDocument document;

  const TextFilePage({super.key, required this.document});

  @override
  ConsumerState<TextFilePage> createState() => _TextFilePageState();
}

class _TextFilePageState extends ConsumerState<TextFilePage> {
  late final TextEditingController _contentController;
  late final TextEditingController _searchController;
  late String _lastSavedText;
  late ExternalFileDocument _document;
  late final String _dirtyOwner = 'external-text-${identityHashCode(this)}';

  bool get _hasUnsavedChanges => _contentController.text != _lastSavedText;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _contentController = TextEditingController(text: _document.content);
    _searchController = TextEditingController();
    _lastSavedText = _document.content;
    _contentController.addListener(_onContentChanged);
    _searchController.addListener(() => setState(() {}));
  }

  void _onContentChanged() {
    WindowCloseGuard.setDirty(_dirtyOwner, _hasUnsavedChanges);
    setState(() {});
  }

  @override
  void dispose() {
    WindowCloseGuard.clear(_dirtyOwner);
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _matchCount {
    final query = _searchController.text;
    if (query.isEmpty) return 0;
    return RegExp(RegExp.escape(query), caseSensitive: false)
        .allMatches(_contentController.text)
        .length;
  }

  Future<void> _copyAll() async {
    final shouldRedact = SecretUtils.containsSecret(
      _contentController.text,
      fileName: _document.name,
    );
    final redacted = await SafeClipboard.copy(
      _contentController.text,
      forceRedaction: shouldRedact,
      fileName: _document.name,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          redacted
              ? 'Copied with likely secrets redacted'
              : 'File content copied',
        ),
      ),
    );
  }

  Future<void> _saveAs() async {
    final path = await ExternalFileService.saveDocumentAs(
      document: _document,
      content: _contentController.text,
    );
    if (!mounted || path == null) return;
    setState(() {
      _lastSavedText = _contentController.text;
    });
    await WindowCloseGuard.clear(_dirtyOwner);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved exported copy')),
    );
  }

  Future<void> _saveOriginal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Overwrite original file?'),
          content: Text(
            'This will overwrite "${_document.name}" on disk.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      final updatedDocument = await ExternalFileService.overwriteOriginal(
        _document,
        _contentController.text,
      );
      if (!mounted) return;
      setState(() {
        _document = updatedDocument;
        _lastSavedText = _contentController.text;
      });
      await WindowCloseGuard.clear(_dirtyOwner);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original file saved safely')),
      );
    } on ExternalFileException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _saveAsSnippet() async {
    final notifier = ref.read(snippetsProvider.notifier);
    final id = await notifier.nextId();
    final shouldRedact = SecretUtils.containsSecret(
      _contentController.text,
      fileName: _document.name,
    );
    await notifier.addSnippet(
      Snippet(
        id: id,
        title: _document.name,
        content: shouldRedact
            ? DataRedactor.redactText(_contentController.text)
            : _contentController.text,
        tags: [
          'external-file',
          if (_document.extension.isNotEmpty) _document.extension,
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldRedact
              ? 'Saved as snippet with likely secrets redacted'
              : 'Saved as snippet',
        ),
      ),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Discard changes and leave this file?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final sizeKb = (_document.sizeBytes / 1024).toStringAsFixed(1);
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _SaveOriginalIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): const _SaveAsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveOriginalIntent: CallbackAction<_SaveOriginalIntent>(
            onInvoke: (_) {
              if (_document.canOverwriteOriginal) {
                _saveOriginal();
              } else {
                _saveAs();
              }
              return null;
            },
          ),
          _SaveAsIntent: CallbackAction<_SaveAsIntent>(
            onInvoke: (_) {
              _saveAs();
              return null;
            },
          ),
        },
        child: PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (await _confirmDiscardChanges() && context.mounted) {
              Navigator.of(context).pop(result);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_document.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'Copy all',
                  onPressed: _copyAll,
                ),
                if (_document.canOverwriteOriginal)
                  IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Save original',
                    onPressed: _saveOriginal,
                  ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save As',
                  onPressed: _saveAs,
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= AppBreakpoints.medium;
                final info = _FileInfoPanel(
                  document: _document,
                  sizeLabel: '$sizeKb KB',
                  canOverwrite: _document.canOverwriteOriginal,
                  hasUnsavedChanges: _hasUnsavedChanges,
                );
                final editor = _EditorPanel(
                  controller: _contentController,
                  searchController: _searchController,
                  matchCount: _matchCount,
                  onSaveSnippet: _saveAsSnippet,
                );
                if (isWide) {
                  return Padding(
                    padding: AppSpacing.page(context),
                    child: Row(
                      children: [
                        SizedBox(width: 330, child: info),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: editor),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: AppSpacing.page(context),
                  children: [
                    SizedBox(height: 220, child: info),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: constraints.maxHeight.clamp(300, 520).toDouble(),
                      child: editor,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FileInfoPanel extends StatelessWidget {
  final ExternalFileDocument document;
  final String sizeLabel;
  final bool canOverwrite;
  final bool hasUnsavedChanges;

  const _FileInfoPanel({
    required this.document,
    required this.sizeLabel,
    required this.canOverwrite,
    required this.hasUnsavedChanges,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListView(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${document.extension.toUpperCase()} · $sizeLabel · ${_encodingLabel(document.encoding)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppBadge(
                label: hasUnsavedChanges ? 'Unsaved' : 'Saved',
                icon: hasUnsavedChanges ? Icons.edit : Icons.check,
                color: hasUnsavedChanges
                    ? AppColors.warning(context)
                    : AppColors.success(context),
                backgroundColor: hasUnsavedChanges
                    ? AppColors.warningContainer(context)
                    : AppColors.successContainer(context),
              ),
              AppBadge(
                label: canOverwrite ? 'Original writable' : 'Read copy',
                icon: canOverwrite ? Icons.save : Icons.copy,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Source', style: Theme.of(context).textTheme.labelLarge),
          SelectableText(
            document.sourceLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (document.isEnvLike)
            AppCard(
              filled: false,
              child: Text(
                '.env files often contain secrets. DevDesk keeps this local; avoid copying or saving secrets into shared locations.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canOverwrite
                ? 'Ctrl+S safely replaces the original after confirmation. Ctrl+Shift+S exports a copy.'
                : 'This platform exposes a safe read copy only. Use Save As to export changes.',
          ),
        ],
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController searchController;
  final int matchCount;
  final VoidCallback onSaveSnippet;

  const _EditorPanel({
    required this.controller,
    required this.searchController,
    required this.matchCount,
    required this.onSaveSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search in file',
                    suffixText: searchController.text.isEmpty
                        ? null
                        : '$matchCount matches',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSaveSnippet,
                icon: const Icon(Icons.note_add),
                label: const Text('Save as Snippet'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              minLines: null,
              maxLines: null,
              style: AppTypography.mono(context),
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'File content',
                fillColor: AppColors.codeBackground(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _encodingLabel(ExternalTextEncoding encoding) {
  return switch (encoding) {
    ExternalTextEncoding.utf8 => 'UTF-8',
    ExternalTextEncoding.utf8Bom => 'UTF-8 BOM',
    ExternalTextEncoding.utf16LittleEndian => 'UTF-16 LE',
    ExternalTextEncoding.utf16BigEndian => 'UTF-16 BE',
  };
}

class _SaveOriginalIntent extends Intent {
  const _SaveOriginalIntent();
}

class _SaveAsIntent extends Intent {
  const _SaveAsIntent();
}
