import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_spacing.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../model/vault_note.dart';
import '../../provider/vault_provider.dart';

class VaultSidebar extends ConsumerWidget {
  const VaultSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(vaultNotesProvider);
    final selectedId = ref.watch(selectedNoteIdProvider);
    final pinned = notes.where((note) => note.isPinned).toList();
    final favorites = ref.watch(favoriteVaultNotesProvider);
    final recent = ref.watch(recentVaultNotesProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _createNewNote(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New Note'),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => _openDailyNote(ref),
                  icon: const Icon(Icons.today),
                  label: const Text('Daily Note'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notes.isEmpty
                ? const AppEmptyState(
                    icon: Icons.folder_open,
                    title: 'Vault empty',
                    message: 'Create a note or open an external Markdown file.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      if (pinned.isNotEmpty)
                        _NoteSection(
                          title: 'Pinned',
                          notes: pinned,
                          selectedId: selectedId,
                          onOpen: (note) => _openNote(context, ref, note),
                          onAction: (action, note) =>
                              _handleNoteAction(context, ref, action, note),
                        ),
                      if (favorites.isNotEmpty)
                        _NoteSection(
                          title: 'Favorites',
                          notes: favorites,
                          selectedId: selectedId,
                          onOpen: (note) => _openNote(context, ref, note),
                          onAction: (action, note) =>
                              _handleNoteAction(context, ref, action, note),
                        ),
                      if (recent.isNotEmpty)
                        _NoteSection(
                          title: 'Recent',
                          notes: recent,
                          selectedId: selectedId,
                          onOpen: (note) => _openNote(context, ref, note),
                          onAction: (action, note) =>
                              _handleNoteAction(context, ref, action, note),
                        ),
                      _FolderTree(
                        notes: notes,
                        selectedId: selectedId,
                        onOpen: (note) => _openNote(context, ref, note),
                        onAction: (action, note) =>
                            _handleNoteAction(context, ref, action, note),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewNote(BuildContext context, WidgetRef ref) async {
    final title = await _askText(
      context,
      title: 'Create note',
      label: 'Note title',
      initialValue: 'Untitled Note',
    );
    if (title == null) return;
    if (!context.mounted) return;
    final folder = await _askText(
      context,
      title: 'Folder',
      label: 'Folder path (optional)',
    );
    final note = await ref.read(vaultNotesProvider.notifier).createNote(
          title: title,
          folderPath: folder ?? '',
        );
    if (!context.mounted) return;
    await _selectNote(context, ref, note);
  }

  Future<void> _openDailyNote(WidgetRef ref) async {
    final note = await ref.read(vaultNotesProvider.notifier).createDailyNote();
    ref.read(selectedNoteIdProvider.notifier).state = note.id;
    _ensureTabOpen(ref, note.id);
  }

  Future<void> _openNote(
    BuildContext context,
    WidgetRef ref,
    VaultNote note,
  ) async {
    final selectedId = ref.read(selectedNoteIdProvider);
    if (selectedId != note.id && !await _confirmSwitch(context, ref)) return;
    if (!context.mounted) return;
    await _selectNote(context, ref, note);
  }

  Future<void> _selectNote(
    BuildContext context,
    WidgetRef ref,
    VaultNote note,
  ) async {
    await ref.read(vaultNotesProvider.notifier).markOpened(note.id);
    ref.read(selectedNoteIdProvider.notifier).state = note.id;
    _ensureTabOpen(ref, note.id);
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _ensureTabOpen(WidgetRef ref, String id) {
    final tabs = [...ref.read(openedNoteIdsProvider)];
    if (!tabs.contains(id)) {
      tabs.add(id);
      ref.read(openedNoteIdsProvider.notifier).state = tabs;
    }
  }

  Future<void> _handleNoteAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    VaultNote note,
  ) async {
    final notifier = ref.read(vaultNotesProvider.notifier);
    switch (action) {
      case 'rename':
        final title = await _askText(
          context,
          title: 'Rename note',
          label: 'Note title',
          initialValue: note.title,
        );
        if (title != null) await notifier.renameNote(note.id, title);
        break;
      case 'move':
        final folder = await _askText(
          context,
          title: 'Move note',
          label: 'Folder path',
          initialValue: note.folderPath,
        );
        if (folder != null) await notifier.moveNote(note.id, folder);
        break;
      case 'duplicate':
        final duplicate = await notifier.duplicateNote(note.id);
        if (duplicate != null && context.mounted) {
          await _selectNote(context, ref, duplicate);
        }
        break;
      case 'favorite':
        await notifier.toggleFavorite(note.id);
        break;
      case 'pin':
        await notifier.togglePinned(note.id);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete note?'),
            content: Text('Delete "${note.title}" from the vault?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await notifier.deleteNote(note.id);
          final tabs = [...ref.read(openedNoteIdsProvider)]..remove(note.id);
          ref.read(openedNoteIdsProvider.notifier).state = tabs;
          if (ref.read(selectedNoteIdProvider) == note.id) {
            ref.read(selectedNoteIdProvider.notifier).state =
                tabs.isEmpty ? null : tabs.last;
          }
        }
        break;
    }
  }

  Future<bool> _confirmSwitch(BuildContext context, WidgetRef ref) async {
    if (!ref.read(vaultHasUnsavedChangesProvider)) return true;
    final switchNote = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'Your draft has been autosaved locally. Switch notes without saving the current note?',
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
    return switchNote == true;
  }

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return value == null || value.trim().isEmpty ? null : value.trim();
  }
}

class _FolderTree extends StatelessWidget {
  final List<VaultNote> notes;
  final String? selectedId;
  final ValueChanged<VaultNote> onOpen;
  final void Function(String action, VaultNote note) onAction;

  const _FolderTree({
    required this.notes,
    required this.selectedId,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final byFolder = <String, List<VaultNote>>{};
    for (final note in notes) {
      byFolder.putIfAbsent(note.folderPath, () => []).add(note);
    }
    final folders = byFolder.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(title: 'Folders'),
        for (final folder in folders)
          ExpansionTile(
            initiallyExpanded: folder.isEmpty,
            leading: Icon(folder.isEmpty ? Icons.home_outlined : Icons.folder),
            title: Text(folder.isEmpty ? 'Vault root' : folder),
            children: [
              for (final note
                  in (byFolder[folder]!
                    ..sort((a, b) => a.title.compareTo(b.title))))
                _NoteTile(
                  note: note,
                  selected: note.id == selectedId,
                  onTap: () => onOpen(note),
                  onAction: (action) => onAction(action, note),
                ),
            ],
          ),
      ],
    );
  }
}

class _NoteSection extends StatelessWidget {
  final String title;
  final List<VaultNote> notes;
  final String? selectedId;
  final ValueChanged<VaultNote> onOpen;
  final void Function(String action, VaultNote note) onAction;

  const _NoteSection({
    required this.title,
    required this.notes,
    required this.selectedId,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(title: title),
        for (final note in notes.take(6))
          _NoteTile(
            note: note,
            selected: note.id == selectedId,
            dense: true,
            onTap: () => onOpen(note),
            onAction: (action) => onAction(action, note),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final VaultNote note;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _NoteTile({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onAction,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      leading:
          Icon(note.isPinned ? Icons.push_pin : Icons.description_outlined),
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        note.tags.isEmpty
            ? note.updatedAt.toString().split('.').first
            : note.tags.map((tag) => '#$tag').join(' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        tooltip: 'Note actions',
        onSelected: onAction,
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'move', child: Text('Move folder')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'favorite',
            child: Text(note.isFavorite ? 'Unfavorite' : 'Favorite'),
          ),
          PopupMenuItem(
            value: 'pin',
            child: Text(note.isPinned ? 'Unpin' : 'Pin'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
