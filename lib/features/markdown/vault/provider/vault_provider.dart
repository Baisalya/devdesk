import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';
import '../model/vault_note.dart';
import '../utils/vault_parser.dart';
import 'vault_template_service.dart';

/// Provider for managing the list of all notes in the vault.
final vaultNotesProvider =
    StateNotifierProvider<VaultNotesNotifier, List<VaultNote>>((ref) {
  return VaultNotesNotifier();
});

class VaultNotesNotifier extends StateNotifier<List<VaultNote>> {
  VaultNotesNotifier() : super([]) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.vaultNotesBox);
    final notes = box.values
        .map((map) => VaultNote.fromMap(Map<String, dynamic>.from(map)))
        .toList();
    state = _sortNotes(_withRecalculatedBacklinks(notes));
    await _persistAll(state);
  }

  Future<VaultNote> createNote({
    String title = 'Untitled Note',
    String content = '',
    String folderPath = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final note = _prepareNote(
      VaultNote(
        title: _uniqueTitle(title),
        content: content,
        folderPath: normalizeFolderPath(folderPath),
        metadata: metadata,
      ),
    );
    await _replaceState([note, ...state]);
    return note;
  }

  Future<VaultNote> createDailyNote([DateTime? date]) async {
    final target = date ?? DateTime.now();
    final title = _dailyTitle(target);
    final existing = state.where((note) => note.title == title).toList();
    if (existing.isNotEmpty) {
      await markOpened(existing.first.id);
      return existing.first;
    }
    return createNote(
      title: title,
      content: VaultTemplateService.dailyNote(target),
      folderPath: 'Daily',
    );
  }

  Future<void> addNote(VaultNote note) async {
    final prepared = _prepareNote(note);
    await _replaceState([prepared, ...state.where((n) => n.id != note.id)]);
  }

  Future<void> updateNote(VaultNote note, {bool saveVersion = true}) async {
    final oldNote = _find(note.id);
    final versions = _nextVersions(oldNote, note, saveVersion: saveVersion);
    final prepared = _prepareNote(
      note.copyWith(
        updatedAt: DateTime.now(),
        versionHistory: versions,
        clearDraftContent: true,
      ),
    );
    await _replaceState([
      for (final n in state)
        if (n.id == prepared.id) prepared else n,
    ]);
  }

  Future<void> updateNoteContent(
    String id,
    String content, {
    bool saveVersion = true,
  }) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(note.copyWith(content: content), saveVersion: saveVersion);
  }

  Future<void> saveDraft(String id, String content) async {
    final note = _find(id);
    if (note == null || note.content == content) return;
    final draft = note.copyWith(
      draftContent: content,
      updatedAt: note.updatedAt,
    );
    await _replaceState([
      for (final n in state)
        if (n.id == id) draft else n,
    ]);
  }

  Future<void> restoreDraft(String id) async {
    final note = _find(id);
    final draft = note?.draftContent;
    if (note == null || draft == null) return;
    await updateNote(note.copyWith(content: draft, clearDraftContent: true));
  }

  Future<void> renameNote(String id, String title) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(note.copyWith(title: _uniqueTitle(title, exceptId: id)));
  }

  Future<void> moveNote(String id, String folderPath) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(
      note.copyWith(folderPath: normalizeFolderPath(folderPath)),
      saveVersion: false,
    );
  }

  Future<VaultNote?> duplicateNote(String id) async {
    final note = _find(id);
    if (note == null) return null;
    final duplicate = _prepareNote(
      VaultNote(
        title: _uniqueTitle('${note.title} Copy'),
        content: note.content,
        folderPath: note.folderPath,
        tags: note.tags,
        links: note.links,
        metadata: Map<String, dynamic>.from(note.metadata),
      ),
    );
    await _replaceState([duplicate, ...state]);
    return duplicate;
  }

  Future<void> deleteNote(String id) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.vaultNotesBox);
    await box.delete(id);
    await _replaceState(state.where((n) => n.id != id).toList());
  }

  Future<void> toggleFavorite(String id) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(
      note.copyWith(isFavorite: !note.isFavorite),
      saveVersion: false,
    );
  }

  Future<void> togglePinned(String id) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(note.copyWith(isPinned: !note.isPinned),
        saveVersion: false);
  }

  Future<void> markOpened(String id) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(
      note.copyWith(lastOpenedAt: DateTime.now()),
      saveVersion: false,
    );
  }

  Future<void> restoreVersion(String id, NoteVersion version) async {
    final note = _find(id);
    if (note == null) return;
    await updateNote(note.copyWith(content: version.content));
  }

  Future<void> importNotes(
    Iterable<VaultNote> notes, {
    bool replace = false,
  }) async {
    final incoming = notes.map(_prepareNote).toList();
    if (replace) {
      await _replaceState(incoming);
      return;
    }
    final merged = [...state];
    for (final note in incoming) {
      merged.removeWhere((existing) => existing.id == note.id);
      merged.add(note);
    }
    await _replaceState(merged);
  }

  VaultNote? _find(String id) {
    for (final note in state) {
      if (note.id == id) return note;
    }
    return null;
  }

  VaultNote _prepareNote(VaultNote note) {
    final frontmatter = VaultParser.parseFrontmatter(note.content);
    return note.copyWith(
      folderPath: normalizeFolderPath(note.folderPath),
      tags: VaultParser.extractAllTags(note.content),
      links: VaultParser.extractWikiLinks(note.content),
      metadata: {
        ...note.metadata,
        ...frontmatter.metadata,
      },
    );
  }

  List<NoteVersion> _nextVersions(
    VaultNote? oldNote,
    VaultNote note, {
    required bool saveVersion,
  }) {
    final history = List<NoteVersion>.from(oldNote?.versionHistory ?? []);
    if (!saveVersion || oldNote == null || oldNote.content == note.content) {
      return history;
    }
    if (history.isEmpty || history.last.content != oldNote.content) {
      history.add(
        NoteVersion(timestamp: oldNote.updatedAt, content: oldNote.content),
      );
    }
    while (history.length > 50) {
      history.removeAt(0);
    }
    return history;
  }

  Future<void> _replaceState(List<VaultNote> notes) async {
    state = _sortNotes(_withRecalculatedBacklinks(notes));
    await _persistAll(state);
  }

  List<VaultNote> _withRecalculatedBacklinks(List<VaultNote> notes) {
    return [
      for (final note in notes)
        note.copyWith(backlinks: VaultParser.notesLinkingTo(note, notes)),
    ];
  }

  Future<void> _persistAll(List<VaultNote> notes) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.vaultNotesBox);
    final currentIds = box.keys.cast<String>().toSet();
    final nextIds = notes.map((note) => note.id).toSet();
    for (final id in currentIds.difference(nextIds)) {
      await box.delete(id);
    }
    for (final note in notes) {
      await box.put(note.id, note.toMap());
    }
  }

  List<VaultNote> _sortNotes(List<VaultNote> notes) {
    final sorted = [...notes];
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aRecent = a.lastOpenedAt ?? a.updatedAt;
      final bRecent = b.lastOpenedAt ?? b.updatedAt;
      return bRecent.compareTo(aRecent);
    });
    return sorted;
  }

  String _uniqueTitle(String title, {String? exceptId}) {
    final trimmed = title.trim().isEmpty ? 'Untitled Note' : title.trim();
    final existing = state
        .where((note) => note.id != exceptId)
        .map((note) => note.title.toLowerCase())
        .toSet();
    if (!existing.contains(trimmed.toLowerCase())) return trimmed;
    var index = 2;
    while (existing.contains('$trimmed $index'.toLowerCase())) {
      index++;
    }
    return '$trimmed $index';
  }

  String _dailyTitle(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

String normalizeFolderPath(String folderPath) {
  return folderPath
      .trim()
      .replaceAll('\\', '/')
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part != '.')
      .join('/');
}

/// Provider for the currently selected note ID.
final selectedNoteIdProvider = StateProvider<String?>((ref) => null);

/// Provider for IDs opened as desktop tabs.
final openedNoteIdsProvider = StateProvider<List<String>>((ref) => const []);

/// Provider for distraction-free writing mode.
final distractionFreeProvider = StateProvider<bool>((ref) => false);

/// Provider for editor font size.
final vaultFontSizeProvider = StateProvider<double>((ref) => 14);

/// Provider for whether the visible editor has unsaved changes.
final vaultHasUnsavedChangesProvider = StateProvider<bool>((ref) => false);

/// Provider used by outline/backlink panels to request an editor jump.
final vaultJumpLineProvider = StateProvider<int?>((ref) => null);

/// Provider for the currently active note.
final activeNoteProvider = Provider<VaultNote?>((ref) {
  final id = ref.watch(selectedNoteIdProvider);
  final notes = ref.watch(vaultNotesProvider);
  if (id == null) return null;
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
});

final vaultFoldersProvider = Provider<List<String>>((ref) {
  final folders = ref
      .watch(vaultNotesProvider)
      .map((note) => note.folderPath)
      .where((folder) => folder.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return folders;
});

final favoriteVaultNotesProvider = Provider<List<VaultNote>>((ref) {
  return ref
      .watch(vaultNotesProvider)
      .where((note) => note.isFavorite)
      .toList();
});

final recentVaultNotesProvider = Provider<List<VaultNote>>((ref) {
  final notes = ref
      .watch(vaultNotesProvider)
      .where((note) => note.lastOpenedAt != null)
      .toList();
  notes.sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
  return notes.take(10).toList();
});
