import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/platform/window_close_guard.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/safe_markdown_image.dart';
import '../../../core/widgets/app_editor_panel.dart';
import '../provider/markdown_provider.dart';

/// Page allowing the user to edit and preview markdown files.
class MarkdownPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const MarkdownPage({super.key, this.initialDocument});

  @override
  ConsumerState<MarkdownPage> createState() => _MarkdownPageState();
}

class _MarkdownPageState extends ConsumerState<MarkdownPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _controller;
  String? _currentFileName;
  ExternalFileDocument? _externalDocument;
  String _lastSavedText = '';
  late final String _dirtyOwner = 'markdown-editor-${identityHashCode(this)}';

  bool get _hasUnsavedChanges => _controller.text != _lastSavedText;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _externalDocument = widget.initialDocument;
    final String initialText =
        widget.initialDocument?.content ?? ref.read(markdownTextProvider);
    _controller = TextEditingController(text: initialText);
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(markdownTextProvider.notifier).state = initialText;
      });
    }
    _lastSavedText = _controller.text;
    _controller.addListener(() {
      ref.read(markdownTextProvider.notifier).state = _controller.text;
      WindowCloseGuard.setDirty(_dirtyOwner, _hasUnsavedChanges);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WindowCloseGuard.clear(_dirtyOwner);
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _insertMarkup(String prefix, {String suffix = ''}) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    final cursorOffset = selectedText.isEmpty
        ? start + prefix.length
        : start + replacement.length;
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Discard changes and continue?'),
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

  Future<void> _newFile() async {
    if (!await _confirmDiscardChanges()) return;
    _controller.clear();
    setState(() {
      _currentFileName = null;
      _externalDocument = null;
      _lastSavedText = '';
    });
    await WindowCloseGuard.clear(_dirtyOwner);
  }

  Future<void> _saveFile({bool saveAs = false}) async {
    var fileName = _currentFileName;
    if (saveAs || fileName == null) {
      fileName = await _askForFileName(title: 'Save Markdown');
    }
    if (fileName == null) return;
    try {
      final normalized = normalizeMarkdownFileName(fileName);
      await saveMarkdownFile(normalized, _controller.text);
      ref.invalidate(markdownFilesProvider);
      setState(() {
        _currentFileName = normalized;
        _externalDocument = null;
        _lastSavedText = _controller.text;
        WindowCloseGuard.clear(_dirtyOwner);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$normalized"')),
      );
    } on ArgumentError catch (e) {
      _showError(e.message ?? e.toString());
    }
  }

  Future<void> _savePrimary() async {
    final external = _externalDocument;
    if (external == null) {
      await _saveFile();
      return;
    }
    if (external.canOverwriteOriginal) {
      await _saveExternalOriginal();
    } else {
      await _saveExternalAs();
    }
  }

  Future<void> _saveExternalOriginal() async {
    final external = _externalDocument;
    if (external == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Overwrite original file?'),
          content: Text('This will overwrite "${external.name}" on disk.'),
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
      final updated = await ExternalFileService.overwriteOriginal(
        external,
        _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _externalDocument = updated;
        _lastSavedText = _controller.text;
      });
      await WindowCloseGuard.clear(_dirtyOwner);
      if (!mounted) return;
    } on ExternalFileException catch (error) {
      if (!mounted) return;
      _showError(error.message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Original markdown file saved')),
    );
  }

  Future<void> _saveExternalAs() async {
    final external = _externalDocument;
    final name = external?.name ?? _currentFileName ?? 'notes.md';
    final path = external == null
        ? await ExternalFileService.saveTextAs(
            suggestedName: _suggestMarkdownExportName(name),
            content: _controller.text,
            allowedExtensions: const ['md', 'markdown', 'txt'],
            dialogTitle: 'Save markdown copy',
          )
        : await ExternalFileService.saveDocumentAs(
            document: external,
            content: _controller.text,
            dialogTitle: 'Save markdown copy',
          );
    if (!mounted || path == null) return;
    setState(() {
      _lastSavedText = _controller.text;
    });
    await WindowCloseGuard.clear(_dirtyOwner);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markdown exported')),
    );
  }

  String _suggestMarkdownExportName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.txt')) {
      return name;
    }
    return normalizeMarkdownFileName(name);
  }

  Future<void> _openFile() async {
    if (!await _confirmDiscardChanges()) return;
    final files = await ref.refresh(markdownFilesProvider.future);
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved markdown files yet')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final name = files[index];
            return ListTile(
              title: Text(name),
              onTap: () async {
                final content = await loadMarkdownFile(name);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (content != null) {
                  _controller.text = content;
                  setState(() {
                    _currentFileName = name;
                    _externalDocument = null;
                    _lastSavedText = content;
                  });
                  await WindowCloseGuard.clear(_dirtyOwner);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _renameFile() async {
    final oldName = _currentFileName;
    if (oldName == null) {
      _showError('Save the file before renaming it.');
      return;
    }
    final newName = await _askForFileName(
      title: 'Rename Markdown',
      initialValue: oldName,
    );
    if (newName == null) return;
    try {
      final normalized = normalizeMarkdownFileName(newName);
      await renameMarkdownFile(oldName, normalized);
      ref.invalidate(markdownFilesProvider);
      setState(() {
        _currentFileName = normalized;
      });
    } on ArgumentError catch (e) {
      _showError(e.message ?? e.toString());
    }
  }

  Future<void> _deleteFile() async {
    final fileName = _currentFileName;
    if (fileName == null) {
      _showError('No saved file is open.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Markdown'),
          content: Text('Delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await deleteMarkdownFile(fileName);
    ref.invalidate(markdownFilesProvider);
    _controller.clear();
    setState(() {
      _currentFileName = null;
      _externalDocument = null;
      _lastSavedText = '';
    });
    await WindowCloseGuard.clear(_dirtyOwner);
  }

  Future<void> _copyMarkdown() async {
    final redacted = await SafeClipboard.copy(_controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          redacted
              ? 'Markdown copied with likely secrets redacted'
              : 'Markdown copied to clipboard',
        ),
      ),
    );
  }

  Future<String?> _askForFileName({
    required String title,
    String initialValue = '',
  }) {
    final filenameController = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: filenameController,
            decoration: const InputDecoration(
              hintText: 'notes.md',
              labelText: 'File name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(filenameController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markdownText = ref.watch(markdownTextProvider);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _newFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          _openFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          _savePrimary();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): () {
          if (_externalDocument == null) {
            _saveFile(saveAs: true);
          } else {
            _saveExternalAs();
          }
        },
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
            title: Text(
              _externalDocument?.name ?? _currentFileName ?? 'Markdown Editor',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: 'New file',
                onPressed: _newFile,
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: 'Open file',
                onPressed: _openFile,
              ),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save file',
                onPressed: _savePrimary,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'save_as':
                      if (_externalDocument == null) {
                        _saveFile(saveAs: true);
                      } else {
                        _saveExternalAs();
                      }
                      break;
                    case 'save_internal':
                      _saveFile(saveAs: true);
                      break;
                    case 'rename':
                      _renameFile();
                      break;
                    case 'delete':
                      _deleteFile();
                      break;
                    case 'copy':
                      _copyMarkdown();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'save_as', child: Text('Save as')),
                  PopupMenuItem(
                    value: 'save_internal',
                    child: Text('Save internal copy'),
                  ),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                  PopupMenuItem(value: 'copy', child: Text('Copy markdown')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _DocumentStatusBar(
                externalDocument: _externalDocument,
                internalName: _currentFileName,
                hasUnsavedChanges: _hasUnsavedChanges,
              ),
              _MarkdownToolbar(onInsert: _insertMarkup),
              Expanded(
                child: Padding(
                  padding:
                      AppSpacing.page(context).copyWith(top: AppSpacing.md),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _MarkdownEditor(controller: _controller),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                                child: _MarkdownPreview(data: markdownText)),
                          ],
                        )
                      : Column(
                          children: [
                            AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              child: TabBar(
                                controller: _tabController,
                                tabs: const [
                                  Tab(text: 'Edit'),
                                  Tab(text: 'Preview'),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _MarkdownEditor(controller: _controller),
                                  _MarkdownPreview(data: markdownText),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentStatusBar extends StatelessWidget {
  final ExternalFileDocument? externalDocument;
  final String? internalName;
  final bool hasUnsavedChanges;

  const _DocumentStatusBar({
    required this.externalDocument,
    required this.internalName,
    required this.hasUnsavedChanges,
  });

  @override
  Widget build(BuildContext context) {
    final document = externalDocument;
    final title = document == null
        ? internalName ?? 'Untitled markdown'
        : 'File: ${document.name}';
    final source = document == null
        ? (internalName == null ? 'Internal draft' : 'Internal file')
        : document.canOverwriteOriginal
            ? 'External file: ${document.sourceLabel}'
            : 'External read copy: use Save As to export changes.';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(document == null ? Icons.edit_document : Icons.folder_open),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: hasUnsavedChanges ? 'Unsaved' : 'Saved',
              icon: hasUnsavedChanges ? Icons.edit : Icons.check,
              color: hasUnsavedChanges ? AppColors.warning : AppColors.success,
              backgroundColor: hasUnsavedChanges
                  ? AppColors.warningContainer(context)
                  : AppColors.successContainer(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  final void Function(String prefix, {String suffix}) onInsert;

  const _MarkdownToolbar({required this.onInsert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _ToolbarButton(
              icon: Icons.title,
              label: 'Heading',
              onPressed: () => onInsert('# '),
            ),
            _ToolbarButton(
              icon: Icons.format_bold,
              label: 'Bold',
              onPressed: () => onInsert('**', suffix: '**'),
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              label: 'Italic',
              onPressed: () => onInsert('*', suffix: '*'),
            ),
            _ToolbarButton(
              icon: Icons.code,
              label: 'Code block',
              onPressed: () => onInsert('```\n', suffix: '\n```'),
            ),
            _ToolbarButton(
              icon: Icons.link,
              label: 'Link',
              onPressed: () => onInsert('[', suffix: '](url)'),
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              label: 'List',
              onPressed: () => onInsert('- '),
            ),
            _ToolbarButton(
              icon: Icons.check_box,
              label: 'Checklist',
              onPressed: () => onInsert('- [ ] '),
            ),
            _ToolbarButton(
              icon: Icons.table_chart,
              label: 'Table',
              onPressed: () => onInsert(
                '\n| Column 1 | Column 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\n',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton.filledTonal(
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;

  const _MarkdownEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppEditorPanel(
      title: 'Editor',
      subtitle: 'Markdown source',
      child: TextField(
        controller: controller,
        expands: true,
        minLines: null,
        maxLines: null,
        style: AppTypography.mono(context),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: true,
          fillColor: AppColors.codeBackground(context),
          hintText: 'Start writing markdown...',
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  final String data;

  const _MarkdownPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const AppEditorPanel(
        title: 'Preview',
        subtitle: 'Rendered document',
        child: AppEmptyState(
          icon: Icons.article_outlined,
          title: 'Preview will appear here',
          message: 'Write Markdown or open a file to render it here.',
        ),
      );
    }
    return AppEditorPanel(
      title: 'Preview',
      subtitle: 'Rendered document',
      child: Markdown(
        data: '$data\n\n',
        imageBuilder: buildSafeMarkdownImage,
        padding: const EdgeInsets.all(AppSpacing.xl),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
          code: AppTypography.mono(context),
        ),
      ),
    );
  }
}
