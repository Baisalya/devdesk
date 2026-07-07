import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_spacing.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/files/external_file_service.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_editor_panel.dart';
import '../../../../snippets/models/snippet.dart';
import '../../../../snippets/provider/snippets_provider.dart';
import '../../model/vault_note.dart';
import '../../provider/vault_export_service.dart';
import '../../provider/vault_provider.dart';
import '../../utils/vault_parser.dart';
import 'vault_toolbar.dart';

class VaultEditor extends ConsumerStatefulWidget {
  final VaultNote note;
  final bool splitPreview;
  final bool showToolbar;

  const VaultEditor({
    super.key,
    required this.note,
    required this.splitPreview,
    this.showToolbar = true,
  });

  @override
  ConsumerState<VaultEditor> createState() => _VaultEditorState();
}

class _VaultEditorState extends ConsumerState<VaultEditor> {
  late final TextEditingController _controller;
  ProviderSubscription<int?>? _jumpSubscription;
  Timer? _draftTimer;
  bool _isPreviewMode = false;
  bool _hasUnsavedChanges = false;
  bool _maskSecretsInPreview = true;
  late String _lastSavedContent;

  @override
  void initState() {
    super.initState();
    final initialContent = widget.note.draftContent ?? widget.note.content;
    _controller = TextEditingController(text: initialContent);
    _lastSavedContent = widget.note.content;
    _hasUnsavedChanges = initialContent != widget.note.content;
    _controller.addListener(_onContentChanged);
    _jumpSubscription = ref.listenManual<int?>(vaultJumpLineProvider, (
      previous,
      next,
    ) {
      if (next == null) return;
      _jumpToLine(next);
      ref.read(vaultJumpLineProvider.notifier).state = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(vaultHasUnsavedChangesProvider.notifier).state =
          _hasUnsavedChanges;
      if (widget.note.draftContent != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored last autosaved draft')),
        );
      }
    });
  }

  @override
  void didUpdateWidget(VaultEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _saveDraftNow(oldWidget.note);
      _controller.removeListener(_onContentChanged);
      final initialContent = widget.note.draftContent ?? widget.note.content;
      _controller.text = initialContent;
      _lastSavedContent = widget.note.content;
      _hasUnsavedChanges = initialContent != widget.note.content;
      _controller.addListener(_onContentChanged);
      ref.read(vaultHasUnsavedChangesProvider.notifier).state =
          _hasUnsavedChanges;
      setState(() {});
    } else if (!_hasUnsavedChanges &&
        widget.note.content != _lastSavedContent) {
      _controller.removeListener(_onContentChanged);
      _controller.text = widget.note.content;
      _lastSavedContent = widget.note.content;
      _controller.addListener(_onContentChanged);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _jumpSubscription?.close();
    _controller.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final changed = _controller.text != _lastSavedContent;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), () {
      _saveDraftNow(widget.note);
    });
    if (changed != _hasUnsavedChanges) {
      _hasUnsavedChanges = changed;
      ref.read(vaultHasUnsavedChangesProvider.notifier).state = changed;
    }
    setState(() {});
  }

  void _saveDraftNow(VaultNote note) {
    if (_controller.text == note.content) return;
    unawaited(
      ref
          .read(vaultNotesProvider.notifier)
          .saveDraft(note.id, _controller.text),
    );
  }

  Future<void> _save() async {
    await ref
        .read(vaultNotesProvider.notifier)
        .updateNoteContent(widget.note.id, _controller.text);
    if (!mounted) return;
    setState(() {
      _lastSavedContent = _controller.text;
      _hasUnsavedChanges = false;
    });
    ref.read(vaultHasUnsavedChangesProvider.notifier).state = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note saved')),
    );
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

  void _insertHeading(int level) {
    _insertMarkup('${List.filled(level, '#').join()} ');
  }

  void _insertToc() {
    final toc = VaultParser.generateTableOfContents(_controller.text);
    _insertMarkup(toc.isEmpty ? '<!-- No headings found -->' : toc);
  }

  void _jumpToLine(int lineIndex) {
    final lines = _controller.text.split('\n');
    var offset = 0;
    for (var i = 0; i < lineIndex && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    _controller.selection = TextSelection.collapsed(offset: offset);
  }

  Future<void> _saveSelectionAsSnippet() async {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _showSnack('Select markdown before saving a snippet.');
      return;
    }
    final selected = selection.textInside(_controller.text).trim();
    if (selected.isEmpty) return;
    final notifier = ref.read(snippetsProvider.notifier);
    final id = await notifier.nextId();
    await notifier.addSnippet(
      Snippet(
        id: id,
        title: '${widget.note.title} snippet',
        content: selected,
        tags: const ['markdown'],
      ),
    );
    if (!mounted) return;
    _showSnack('Saved selected markdown as snippet');
  }

  Future<void> _insertSnippet() async {
    final snippets = ref.read(snippetsProvider).value ?? const <Snippet>[];
    final selected = await showDialog<Snippet>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Insert snippet'),
          children: [
            if (snippets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('No snippets saved yet.'),
              )
            else
              for (final snippet in snippets)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(snippet),
                  child: Text(snippet.title),
                ),
          ],
        );
      },
    );
    if (selected == null) return;
    _insertMarkup(selected.content);
  }

  Future<void> _showSearchReplace() async {
    final searchController = TextEditingController();
    final replaceController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search and replace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(labelText: 'Find'),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: replaceController,
                decoration: const InputDecoration(labelText: 'Replace with'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                final query = searchController.text;
                final index = _controller.text.indexOf(query);
                if (query.isEmpty || index < 0) return;
                _controller.selection = TextSelection(
                  baseOffset: index,
                  extentOffset: index + query.length,
                );
              },
              child: const Text('Find'),
            ),
            FilledButton(
              onPressed: () {
                final query = searchController.text;
                if (query.isEmpty) return;
                _controller.text =
                    _controller.text.replaceAll(query, replaceController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Replace all'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showVersionDiff() async {
    final previous = widget.note.versionHistory.isEmpty
        ? null
        : widget.note.versionHistory.last;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Markdown diff'),
          content: SizedBox(
            width: 760,
            height: 460,
            child: previous == null
                ? const Center(child: Text('No previous version saved yet.'))
                : Row(
                    children: [
                      Expanded(
                        child: _ReadOnlyDiffPane(
                          title: 'Previous',
                          content: previous.content,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ReadOnlyDiffPane(
                          title: 'Current',
                          content: _controller.text,
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _export(String format) async {
    final hasSecrets = VaultParser.containsSecrets(_controller.text);
    var maskSecrets = true;
    if (hasSecrets) {
      final exportUnmasked = await _confirmUnmaskedExport();
      maskSecrets = exportUnmasked != true;
    }
    final note = widget.note.copyWith(content: _controller.text);
    switch (format) {
      case 'md':
        await ExternalFileService.saveTextAs(
          suggestedName: note.fileName,
          content: VaultExportService.exportMarkdown(
            note,
            maskSecrets: maskSecrets,
          ),
          allowedExtensions: const ['md', 'markdown'],
          dialogTitle: 'Export Markdown',
        );
        break;
      case 'txt':
        await ExternalFileService.saveTextAs(
          suggestedName: '${note.title}.txt',
          content:
              VaultExportService.exportText(note, maskSecrets: maskSecrets),
          allowedExtensions: const ['txt'],
          dialogTitle: 'Export Text',
        );
        break;
      case 'html':
        await ExternalFileService.saveTextAs(
          suggestedName: '${note.title}.html',
          content: VaultExportService.exportToHtml(
            note,
            maskSecrets: maskSecrets,
          ),
          allowedExtensions: const ['html'],
          dialogTitle: 'Export HTML',
        );
        break;
      case 'pdf':
        await ExternalFileService.saveBytesAs(
          suggestedName: '${note.title}.pdf',
          bytes: Uint8List.fromList(
            utf8PdfBytes(
              note.title,
              VaultExportService.exportText(note, maskSecrets: maskSecrets),
            ),
          ),
          allowedExtensions: const ['pdf'],
          dialogTitle: 'Export PDF',
        );
        break;
    }
  }

  Future<bool?> _confirmUnmaskedExport() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Potential secrets detected'),
          content: const Text(
            'Preview and exports mask API keys, tokens, passwords, private keys, Authorization headers, and Bearer values unless you explicitly export unmasked content.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Export masked'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Export unmasked'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRevealSecrets() async {
    final reveal = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reveal possible secrets?'),
          content: const Text(
            'This note may contain keys or tokens. DevDesk stays local, but reveal only when you intend to inspect the raw values.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep masked'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reveal'),
            ),
          ],
        );
      },
    );
    if (reveal == true) {
      setState(() => _maskSecretsInPreview = false);
    }
  }

  Future<void> _copyCodeBlocks() async {
    final matches = RegExp(r'```[a-zA-Z0-9_-]*\n([\s\S]*?)```')
        .allMatches(_controller.text)
        .map((match) => match.group(1)!.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    if (matches.isEmpty) {
      _showSnack('No fenced code blocks found.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: matches.join('\n\n')));
    if (!mounted) return;
    _showSnack('Copied ${matches.length} code block(s)');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(vaultFontSizeProvider);
    final hasSecrets = VaultParser.containsSecrets(_controller.text);
    final previewContent = hasSecrets && _maskSecretsInPreview
        ? VaultParser.maskSecrets(_controller.text)
        : _controller.text;

    final editor = _VaultEditorField(
      controller: _controller,
      fontSize: fontSize,
    );
    final preview = _VaultPreview(
      content: previewContent,
      hasSecrets: hasSecrets,
      maskSecrets: _maskSecretsInPreview,
      onRevealSecrets: _confirmRevealSecrets,
      onCopyCodeBlocks: _copyCodeBlocks,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          unawaited(_save());
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          _insertMarkup('**', suffix: '**');
        },
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          _insertMarkup('*', suffix: '*');
        },
      },
      child: Column(
        children: [
          _EditorHeader(
            note: widget.note,
            hasUnsavedChanges: _hasUnsavedChanges,
            onSave: _save,
            onExport: _export,
            onToggleFavorite: () => ref
                .read(vaultNotesProvider.notifier)
                .toggleFavorite(widget.note.id),
            onTogglePinned: () => ref
                .read(vaultNotesProvider.notifier)
                .togglePinned(widget.note.id),
            onToggleDistractionFree: () {
              final notifier = ref.read(distractionFreeProvider.notifier);
              notifier.state = !ref.read(distractionFreeProvider);
            },
            onIncreaseFont: () =>
                ref.read(vaultFontSizeProvider.notifier).state = fontSize + 1,
            onDecreaseFont: () =>
                ref.read(vaultFontSizeProvider.notifier).state = fontSize - 1,
            onSearchReplace: _showSearchReplace,
            onVersionDiff: _showVersionDiff,
          ),
          if (widget.showToolbar)
            VaultToolbar(
              onInsert: _insertMarkup,
              onHeading: _insertHeading,
              onInsertToc: _insertToc,
              onTogglePreview: () =>
                  setState(() => _isPreviewMode = !_isPreviewMode),
              onInsertSnippet: _insertSnippet,
              onSaveSelectionAsSnippet: _saveSelectionAsSnippet,
              isPreviewMode: _isPreviewMode,
              showPreviewToggle: !widget.splitPreview,
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: widget.splitPreview
                  ? Row(
                      children: [
                        Expanded(child: editor),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: preview),
                      ],
                    )
                  : (_isPreviewMode ? preview : editor),
            ),
          ),
          _EditorFooter(content: _controller.text),
        ],
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  final VaultNote note;
  final bool hasUnsavedChanges;
  final Future<void> Function() onSave;
  final ValueChanged<String> onExport;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleDistractionFree;
  final VoidCallback onIncreaseFont;
  final VoidCallback onDecreaseFont;
  final VoidCallback onSearchReplace;
  final VoidCallback onVersionDiff;

  const _EditorHeader({
    required this.note,
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.onExport,
    required this.onToggleFavorite,
    required this.onTogglePinned,
    required this.onToggleDistractionFree,
    required this.onIncreaseFont,
    required this.onDecreaseFont,
    required this.onSearchReplace,
    required this.onVersionDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  note.folderPath.isEmpty ? 'Vault root' : note.folderPath,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasUnsavedChanges)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: Tooltip(
                message: 'Unsaved changes',
                child: Icon(Icons.circle, size: 12, color: Colors.orange),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save (Ctrl+S)',
            onPressed: hasUnsavedChanges ? () => unawaited(onSave()) : null,
          ),
          IconButton(
            icon: Icon(note.isFavorite ? Icons.star : Icons.star_border),
            tooltip: 'Favorite',
            onPressed: onToggleFavorite,
          ),
          IconButton(
            icon:
                Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: 'Pin',
            onPressed: onTogglePinned,
          ),
          PopupMenuButton<String>(
            tooltip: 'More note actions',
            onSelected: (value) {
              switch (value) {
                case 'find':
                  onSearchReplace();
                  break;
                case 'diff':
                  onVersionDiff();
                  break;
                case 'focus':
                  onToggleDistractionFree();
                  break;
                case 'font_up':
                  onIncreaseFont();
                  break;
                case 'font_down':
                  onDecreaseFont();
                  break;
                case 'md':
                case 'txt':
                case 'html':
                case 'pdf':
                  onExport(value);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'find', child: Text('Search / replace')),
              PopupMenuItem(
                  value: 'diff', child: Text('Diff with last version')),
              PopupMenuItem(
                  value: 'focus', child: Text('Distraction-free mode')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'font_up', child: Text('Increase font size')),
              PopupMenuItem(
                  value: 'font_down', child: Text('Decrease font size')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'md', child: Text('Export .md')),
              PopupMenuItem(value: 'txt', child: Text('Export .txt')),
              PopupMenuItem(value: 'html', child: Text('Export .html')),
              PopupMenuItem(value: 'pdf', child: Text('Export .pdf')),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultEditorField extends StatelessWidget {
  final TextEditingController controller;
  final double fontSize;

  const _VaultEditorField({
    required this.controller,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AppEditorPanel(
      title: 'Editor',
      subtitle: 'Markdown source',
      child: TextField(
        controller: controller,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        style: AppTypography.mono(context, fontSize: fontSize).copyWith(
          height: 1.6,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start writing...',
          fillColor: AppColors.codeBackground(context),
          filled: true,
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
      ),
    );
  }
}

class _VaultPreview extends StatelessWidget {
  final String content;
  final bool hasSecrets;
  final bool maskSecrets;
  final VoidCallback onRevealSecrets;
  final VoidCallback onCopyCodeBlocks;

  const _VaultPreview({
    required this.content,
    required this.hasSecrets,
    required this.maskSecrets,
    required this.onRevealSecrets,
    required this.onCopyCodeBlocks,
  });

  @override
  Widget build(BuildContext context) {
    final cleanContent = VaultParser.stripFrontmatter(content);
    return AppEditorPanel(
      title: 'Preview',
      subtitle:
          hasSecrets && maskSecrets ? 'Secrets masked' : 'Rendered document',
      actions: [
        if (hasSecrets && maskSecrets)
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Reveal secrets',
            onPressed: onRevealSecrets,
          ),
        IconButton(
          icon: const Icon(Icons.copy_all),
          tooltip: 'Copy code blocks',
          onPressed: onCopyCodeBlocks,
        ),
      ],
      child: cleanContent.trim().isEmpty
          ? const AppEmptyState(
              icon: Icons.article_outlined,
              title: 'Preview will appear here',
              message: 'Write Markdown or open a note to render it here.',
            )
          : Markdown(
              data: '$cleanContent\n\n',
              selectable: true,
              padding: const EdgeInsets.all(AppSpacing.md),
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                code: AppTypography.mono(context),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.codeBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}

class _ReadOnlyDiffPane extends StatelessWidget {
  final String title;
  final String content;

  const _ReadOnlyDiffPane({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return AppEditorPanel(
      title: title,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SelectableText(
          content,
          style: AppTypography.mono(context),
        ),
      ),
    );
  }
}

class _EditorFooter extends StatelessWidget {
  final String content;

  const _EditorFooter({required this.content});

  @override
  Widget build(BuildContext context) {
    final stats = VaultParser.stats(content);
    final tags = VaultParser.extractAllTags(content);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('${stats.words} words',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpacing.md),
            Text('${stats.characters} chars',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpacing.md),
            Text('${stats.readingMinutes} min read',
                style: Theme.of(context).textTheme.bodySmall),
            if (tags.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                tags.map((tag) => '#$tag').join('  '),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (VaultParser.containsSecrets(content))
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Tooltip(
                  message: 'Potential secrets detected',
                  child: Icon(Icons.warning, size: 16, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<int> utf8PdfBytes(String title, String text) {
  String esc(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');

  final lines = text
      .replaceAll('\r\n', '\n')
      .split('\n')
      .expand((line) => line.length <= 90
          ? [line]
          : RegExp('.{1,90}').allMatches(line).map((m) => m.group(0)!))
      .take(42)
      .toList();
  final stream = StringBuffer()
    ..writeln('BT')
    ..writeln('/F1 18 Tf')
    ..writeln('50 780 Td')
    ..writeln('(${esc(title)}) Tj')
    ..writeln('/F1 10 Tf')
    ..writeln('0 -28 Td');
  for (final line in lines) {
    stream
      ..writeln('(${esc(line)}) Tj')
      ..writeln('0 -14 Td');
  }
  stream.writeln('ET');
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer
      ..writeln('${i + 1} 0 obj')
      ..writeln(objects[i])
      ..writeln('endobj');
  }
  final xrefOffset = buffer.length;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (var i = 1; i < offsets.length; i++) {
    buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln(xrefOffset)
    ..writeln('%%EOF');
  return Uint8List.fromList(buffer.toString().codeUnits);
}
