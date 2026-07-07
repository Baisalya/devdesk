import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_breakpoints.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/files/external_file.dart';
import '../../../../core/files/external_file_service.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../model/vault_note.dart';
import '../provider/vault_export_service.dart';
import '../provider/vault_provider.dart';
import '../utils/vault_parser.dart';
import 'dialogs/command_palette.dart';
import 'dialogs/quick_switcher.dart';
import 'widgets/vault_editor.dart';
import 'widgets/vault_inspector.dart';
import 'widgets/vault_sidebar.dart';

class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showInspector = true;

  void _openQuickSwitcher() {
    showDialog<void>(context: context, builder: (_) => const QuickSwitcher());
  }

  void _openCommandPalette() {
    showDialog<void>(context: context, builder: (_) => const CommandPalette());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = AppBreakpoints.isCompact(width);
    final isExpanded = AppBreakpoints.isExpanded(width);
    final activeNote = ref.watch(activeNoteProvider);
    final distractionFree = ref.watch(distractionFreeProvider);
    final hasUnsavedChanges = ref.watch(vaultHasUnsavedChangesProvider);

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeaveUnsaved() && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Markdown Vault'),
          leading: isCompact && !distractionFree
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open navigation menu',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _openQuickSwitcher,
              tooltip: 'Quick Switcher (Ctrl+P)',
            ),
            IconButton(
              icon: const Icon(Icons.terminal),
              onPressed: _openCommandPalette,
              tooltip: 'Command Palette (Ctrl+K)',
            ),
            PopupMenuButton<String>(
              tooltip: 'Vault actions',
              onSelected: (value) {
                _handleVaultAction(value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'open_md', child: Text('Open external Markdown')),
                PopupMenuItem(
                    value: 'import_zip', child: Text('Import vault ZIP')),
                PopupMenuDivider(),
                PopupMenuItem(
                    value: 'export_zip', child: Text('Export vault ZIP')),
                PopupMenuItem(
                    value: 'export_json', child: Text('Export vault JSON')),
              ],
            ),
            if (!isCompact)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () =>
                    setState(() => _showInspector = !_showInspector),
                color: _showInspector
                    ? Theme.of(context).colorScheme.primary
                    : null,
                tooltip: 'Toggle Inspector',
              ),
          ],
        ),
        drawer: isCompact && !distractionFree
            ? const Drawer(child: VaultSidebar())
            : null,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyP, control: true):
                _openQuickSwitcher,
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _openCommandPalette,
          },
          child: Focus(
            autofocus: true,
            child: distractionFree
                ? _EditorOrEmpty(
                    activeNote: activeNote,
                    splitPreview: false,
                    showToolbar: true,
                    onCreateNote: _createFirstNote,
                  )
                : Row(
                    children: [
                      if (!isCompact) ...[
                        const SizedBox(width: 280, child: VaultSidebar()),
                        const VerticalDivider(width: 1),
                      ],
                      Expanded(
                        child: Column(
                          children: [
                            if (!isCompact) _DesktopTabs(onSelect: _selectNote),
                            Expanded(
                              child: _EditorOrEmpty(
                                activeNote: activeNote,
                                splitPreview: !isCompact,
                                showToolbar: true,
                                onCreateNote: _createFirstNote,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact &&
                          _showInspector &&
                          activeNote != null) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: isExpanded ? 340 : 280,
                          child: VaultInspector(
                            note: activeNote,
                            onJumpToHeading: (line) {
                              ref.read(vaultJumpLineProvider.notifier).state =
                                  line;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleVaultAction(String action) async {
    switch (action) {
      case 'open_md':
        await _openExternalMarkdown();
        break;
      case 'import_zip':
        await _importVaultZip();
        break;
      case 'export_zip':
        await VaultExportService.exportVaultAsZip(ref.read(vaultNotesProvider));
        break;
      case 'export_json':
        await VaultExportService.exportVaultAsJson(
            ref.read(vaultNotesProvider));
        break;
    }
  }

  Future<void> _createFirstNote() async {
    final note = await ref.read(vaultNotesProvider.notifier).createNote(
          title: 'Welcome',
          content: '# Welcome\n\nStart writing in your DevDesk vault.',
        );
    _openTab(note.id);
    ref.read(selectedNoteIdProvider.notifier).state = note.id;
  }

  Future<void> _selectNote(String id) async {
    if (id == ref.read(selectedNoteIdProvider)) return;
    if (!await _confirmSwitch()) return;
    await ref.read(vaultNotesProvider.notifier).markOpened(id);
    ref.read(selectedNoteIdProvider.notifier).state = id;
  }

  Future<void> _openExternalMarkdown() async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();
      if (document == null) return;
      if (document.kind != DevFileKind.markdown) {
        _showSnack('Choose a .md, .markdown, or README.md file.');
        return;
      }
      if (VaultParser.containsSecrets(document.content)) {
        final proceed = await _confirmSecretOpen(document.name);
        if (proceed != true) return;
      }
      final note = VaultNote(
        title: _titleFromFileName(document.name),
        content: document.content,
        folderPath: 'External',
        externalPath: document.path,
      );
      await ref.read(vaultNotesProvider.notifier).addNote(note);
      _openTab(note.id);
      ref.read(selectedNoteIdProvider.notifier).state = note.id;
      _showSnack('Opened ${document.name} in the vault');
    } on ExternalFileException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not open Markdown: $e');
    }
  }

  Future<void> _importVaultZip() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Import Markdown vault ZIP',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        allowMultiple: false,
        withData: true,
        lockParentWindow: true,
      );
      final files = result?.files ?? const <PlatformFile>[];
      final file = files.length == 1 ? files.first : null;
      if (file == null) return;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        _showSnack('Could not read selected ZIP.');
        return;
      }
      final imported = VaultExportService.importZipBytes(bytes);
      if (imported.isEmpty) {
        _showSnack('No markdown files found in ZIP.');
        return;
      }
      await ref.read(vaultNotesProvider.notifier).importNotes(imported);
      _openTab(imported.first.id);
      ref.read(selectedNoteIdProvider.notifier).state = imported.first.id;
      _showSnack('Imported ${imported.length} note(s)');
    } on FormatException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not import vault ZIP: $e');
    }
  }

  Future<bool> _confirmSwitch() async {
    if (!ref.read(vaultHasUnsavedChangesProvider)) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'Your draft has been autosaved locally. Switch notes without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<bool> _confirmLeaveUnsaved() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'Your draft has been autosaved locally. Leave the vault without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<bool?> _confirmSecretOpen(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potential secrets detected'),
        content: Text(
          '"$name" may contain API keys or tokens. DevDesk keeps this local, and preview/export will mask secret-looking values by default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open locally'),
          ),
        ],
      ),
    );
  }

  void _openTab(String id) {
    final tabs = [...ref.read(openedNoteIdsProvider)];
    if (!tabs.contains(id)) {
      tabs.add(id);
      ref.read(openedNoteIdsProvider.notifier).state = tabs;
    }
  }

  String _titleFromFileName(String name) {
    return name
        .replaceFirst(RegExp(r'\.markdown$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorOrEmpty extends StatelessWidget {
  final VaultNote? activeNote;
  final bool splitPreview;
  final bool showToolbar;
  final Future<void> Function() onCreateNote;

  const _EditorOrEmpty({
    required this.activeNote,
    required this.splitPreview,
    required this.showToolbar,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    final note = activeNote;
    if (note == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppEmptyState(
            icon: Icons.article_outlined,
            title: 'No note selected',
            message:
                'Create a note, open one from the folder tree, or import a vault.',
            action: FilledButton.icon(
              onPressed: () {
                onCreateNote();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create note'),
            ),
          ),
        ),
      );
    }
    return VaultEditor(
      note: note,
      splitPreview: splitPreview,
      showToolbar: showToolbar,
    );
  }
}

class _DesktopTabs extends ConsumerWidget {
  final Future<void> Function(String id) onSelect;

  const _DesktopTabs({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(vaultNotesProvider);
    final selectedId = ref.watch(selectedNoteIdProvider);
    final tabIds = ref.watch(openedNoteIdsProvider);
    final tabNotes = [
      for (final id in tabIds)
        for (final note in notes)
          if (note.id == id) note,
    ];
    if (tabNotes.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final note in tabNotes)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: AppSpacing.xs,
                ),
                child: InputChip(
                  selected: note.id == selectedId,
                  label: Text(
                    note.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  onPressed: () {
                    onSelect(note.id);
                  },
                  onDeleted: () => _closeTab(ref, note.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _closeTab(WidgetRef ref, String id) {
    final tabs = [...ref.read(openedNoteIdsProvider)]..remove(id);
    ref.read(openedNoteIdsProvider.notifier).state = tabs;
    if (ref.read(selectedNoteIdProvider) == id) {
      ref.read(selectedNoteIdProvider.notifier).state =
          tabs.isEmpty ? null : tabs.last;
    }
  }
}
