import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
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
    });
  }

  @override
  void dispose() {
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
    await ExternalFileService.overwriteOriginal(external, _controller.text);
    if (!mounted) return;
    setState(() {
      _lastSavedText = _controller.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Original markdown file saved')),
    );
  }

  Future<void> _saveExternalAs() async {
    final name = _externalDocument?.name ?? _currentFileName ?? 'notes.md';
    final path = await ExternalFileService.saveTextAs(
      suggestedName: _suggestMarkdownExportName(name),
      content: _controller.text,
      allowedExtensions: const ['md', 'markdown', 'txt'],
      dialogTitle: 'Save markdown copy',
    );
    if (!mounted || path == null) return;
    setState(() {
      _lastSavedText = _controller.text;
    });
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
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markdown copied to clipboard')),
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
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    return PopScope(
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
          bottom: isWide
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'Edit'), Tab(text: 'Preview')],
                ),
        ),
        body: Column(
          children: [
            if (_externalDocument != null)
              _ExternalSourceBanner(document: _externalDocument!),
            _MarkdownToolbar(onInsert: _insertMarkup),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                            child: _MarkdownEditor(controller: _controller)),
                        const VerticalDivider(width: 1),
                        Expanded(child: _MarkdownPreview(data: markdownText)),
                      ],
                    )
                  : TabBarView(
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
    );
  }
}

class _ExternalSourceBanner extends StatelessWidget {
  final ExternalFileDocument document;

  const _ExternalSourceBanner({required this.document});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.folder_open, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                document.canOverwriteOriginal
                    ? 'External file: ${document.sourceLabel}'
                    : 'External read copy: use Save As to export changes.',
                overflow: TextOverflow.ellipsis,
              ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.title),
            tooltip: 'Heading',
            onPressed: () => onInsert('# '),
          ),
          IconButton(
            icon: const Icon(Icons.format_bold),
            tooltip: 'Bold',
            onPressed: () => onInsert('**', suffix: '**'),
          ),
          IconButton(
            icon: const Icon(Icons.format_italic),
            tooltip: 'Italic',
            onPressed: () => onInsert('*', suffix: '*'),
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code block',
            onPressed: () => onInsert('```\n', suffix: '\n```'),
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Link',
            onPressed: () => onInsert('[', suffix: '](url)'),
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: 'List',
            onPressed: () => onInsert('- '),
          ),
          IconButton(
            icon: const Icon(Icons.check_box),
            tooltip: 'Checklist',
            onPressed: () => onInsert('- [ ] '),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Table',
            onPressed: () => onInsert(
              '\n| Column 1 | Column 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\n',
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;

  const _MarkdownEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: controller,
        expands: true,
        minLines: null,
        maxLines: null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Start writing markdown...',
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
      return const Center(child: Text('Preview will appear here'));
    }
    return Markdown(data: data);
  }
}
