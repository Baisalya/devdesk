import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/markdown/vault/model/vault_note.dart';
import 'package:devdesk/features/markdown/vault/presentation/vault_page.dart';
import 'package:devdesk/features/markdown/vault/provider/vault_provider.dart';
import 'package:devdesk/features/markdown/vault/utils/vault_parser.dart';

void main() {
  setUp(() {
    seededNotes.clear();
  });

  testWidgets('Vault empty state renders', (tester) async {
    await pumpVault(tester, const Size(1366, 768));

    expect(find.text('Vault empty'), findsOneWidget);
    expect(find.text('No note selected'), findsOneWidget);
  });

  testWidgets('Create note from empty state', (tester) async {
    await pumpVault(tester, const Size(1366, 768));

    await tester.tap(find.text('Create note'));
    await pumpUi(tester);

    expect(find.text('Welcome'), findsWidgets);
  });

  testWidgets('Rename, duplicate and delete note from folder tree',
      (tester) async {
    await seedNote(title: 'Alpha', content: '# Alpha');
    await pumpVault(tester, const Size(1366, 768));

    await tester.tap(find.byTooltip('Note actions').first);
    await pumpUi(tester);
    await tester.tap(find.text('Rename'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Gamma');
    await tester.tap(find.text('Save').last);
    await pumpUi(tester);
    expect(find.text('Gamma'), findsWidgets);

    await tester.tap(find.byTooltip('Note actions').first);
    await pumpUi(tester);
    await tester.tap(find.text('Duplicate'));
    await pumpUi(tester);
    expect(find.text('Gamma Copy'), findsWidgets);

    await tester.tap(find.byTooltip('Note actions').first);
    await pumpUi(tester);
    await tester.tap(find.text('Delete'));
    await pumpUi(tester);
    await tester.tap(find.text('Delete').last);
    await pumpUi(tester);
    expect(find.text('Gamma Copy'), findsNothing);
  });

  testWidgets('Open note from folder tree shows editor content',
      (tester) async {
    final note = await seedNote(title: 'Seed', content: '# Seed');
    await pumpVault(tester, const Size(1366, 768));

    await tester.tap(find.text('Seed').first);
    await pumpUi(tester);

    expect(find.text(note.title), findsWidgets);
    expect(find.text('Seed'), findsWidgets);
  });

  testWidgets('Android edit preview toggle works', (tester) async {
    final note = await seedNote(title: 'Mobile', content: '# Mobile title');
    await pumpVault(tester, const Size(360, 800), selectedId: note.id);

    await tester.tap(find.byTooltip('Preview'));
    await pumpUi(tester);

    expect(find.text('Rendered document'), findsOneWidget);
    expect(find.text('Mobile title'), findsWidgets);
  });

  testWidgets('Windows split editor preview layout renders', (tester) async {
    final note = await seedNote(title: 'Desktop', content: '# Desktop title');
    await pumpVault(tester, const Size(1366, 768), selectedId: note.id);

    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Desktop title'), findsWidgets);
  });

  testWidgets('Toolbar inserts markdown', (tester) async {
    final note = await seedNote(title: 'Toolbar', content: '');
    await pumpVault(tester, const Size(1366, 768), selectedId: note.id);

    await tester.tap(find.text('H1').first);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '# ');
  });

  testWidgets('Command palette opens and template creates a note',
      (tester) async {
    await pumpVault(tester, const Size(1366, 768));

    await tester.tap(find.byTooltip('Command Palette (Ctrl+K)'));
    await pumpUi(tester);
    expect(find.text('Type a command...'), findsOneWidget);

    await tester.tap(find.text('Template: README'));
    await pumpUi(tester);
    expect(find.text('README'), findsWidgets);
  });

  testWidgets('Quick switcher filters notes', (tester) async {
    await seedNote(title: 'Alpha', content: 'first');
    await seedNote(title: 'Beta', content: 'second match');
    await pumpVault(tester, const Size(1366, 768));

    await tester.tap(find.byTooltip('Quick Switcher (Ctrl+P)'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Beta');
    await pumpUi(tester);

    final dialog = find.byType(Dialog);
    expect(
        find.descendant(of: dialog, matching: find.text('Beta')), findsWidgets);
    expect(find.descendant(of: dialog, matching: find.text('Alpha')),
        findsNothing);
  });

  testWidgets('Outline, backlinks and tags panels render note metadata',
      (tester) async {
    await seedNote(title: 'Source', content: 'Link to [[Target]]');
    final target =
        await seedNote(title: 'Target', content: '# Heading\n\nBody #tagged');
    await pumpVault(tester, const Size(1366, 768), selectedId: target.id);
    expect(find.text('Heading'), findsWidgets);

    await tester.tap(find.text('Links'));
    await pumpUi(tester);
    expect(find.text('Source'), findsWidgets);

    await tester.tap(find.text('Tags'));
    await pumpUi(tester);
    expect(find.text('#tagged'), findsWidgets);
  });

  testWidgets('Unsaved changes warning appears when switching notes',
      (tester) async {
    final one = await seedNote(title: 'One', content: 'Original');
    await seedNote(title: 'Two', content: 'Second');
    await pumpVault(tester, const Size(1366, 768), selectedId: one.id);

    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.pump();
    await tester.tap(find.text('Two').first);
    await pumpUi(tester);

    expect(find.text('Unsaved changes'), findsOneWidget);
  });

  testWidgets('Vault has no overflow at key responsive sizes', (tester) async {
    const sizes = [
      Size(360, 800),
      Size(800, 1280),
      Size(1366, 768),
      Size(1920, 1080),
    ];

    for (final size in sizes) {
      await clearVault();
      final note =
          await seedNote(title: 'Responsive', content: '# Responsive\n\n#tag');
      await pumpVault(tester, size, selectedId: note.id);
      expect(tester.takeException(), isNull, reason: 'No overflow at $size');
    }
  });
}

Future<void> pumpVault(
  WidgetTester tester,
  Size size, {
  String? selectedId,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultNotesProvider.overrideWith(
          (ref) => MemoryVaultNotesNotifier(seededNotes),
        ),
        if (selectedId != null)
          selectedNoteIdProvider.overrideWith((ref) => selectedId),
        if (selectedId != null)
          openedNoteIdsProvider.overrideWith((ref) => [selectedId]),
      ],
      child: const MaterialApp(home: VaultPage()),
    ),
  );
  await pumpUi(tester);
}

Future<void> pumpUi(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<VaultNote> seedNote({
  required String title,
  required String content,
  String folderPath = '',
}) async {
  final note = VaultNote(
    title: title,
    content: content,
    folderPath: folderPath,
  );
  seededNotes.add(note);
  return note;
}

Future<void> clearVault() async {
  seededNotes.clear();
}

final seededNotes = <VaultNote>[];

class MemoryVaultNotesNotifier extends VaultNotesNotifier {
  MemoryVaultNotesNotifier(List<VaultNote> notes) : super() {
    state = _prepared(notes);
  }

  @override
  Future<void> loadNotes() async {}

  @override
  Future<VaultNote> createNote({
    String title = 'Untitled Note',
    String content = '',
    String folderPath = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final note = VaultNote(
      title: title,
      content: content,
      folderPath: folderPath,
      metadata: metadata,
    );
    state = _prepared([note, ...state]);
    return note;
  }

  @override
  Future<void> renameNote(String id, String title) async {
    state = _prepared([
      for (final note in state)
        if (note.id == id) note.copyWith(title: title) else note,
    ]);
  }

  @override
  Future<VaultNote?> duplicateNote(String id) async {
    final note = state.where((note) => note.id == id).firstOrNull;
    if (note == null) return null;
    final duplicate = VaultNote(
      title: '${note.title} Copy',
      content: note.content,
      folderPath: note.folderPath,
    );
    state = _prepared([duplicate, ...state]);
    return duplicate;
  }

  @override
  Future<void> deleteNote(String id) async {
    state = _prepared(state.where((note) => note.id != id).toList());
  }

  @override
  Future<void> markOpened(String id) async {
    state = _prepared([
      for (final note in state)
        if (note.id == id)
          note.copyWith(lastOpenedAt: DateTime.now())
        else
          note,
    ]);
  }

  @override
  Future<void> updateNoteContent(
    String id,
    String content, {
    bool saveVersion = true,
  }) async {
    state = _prepared([
      for (final note in state)
        if (note.id == id) note.copyWith(content: content) else note,
    ]);
  }

  @override
  Future<void> saveDraft(String id, String content) async {
    state = _prepared([
      for (final note in state)
        if (note.id == id) note.copyWith(draftContent: content) else note,
    ]);
  }

  static List<VaultNote> _prepared(List<VaultNote> notes) {
    return [
      for (final note in notes)
        note.copyWith(
          tags: VaultParser.extractAllTags(note.content),
          links: VaultParser.extractWikiLinks(note.content),
          backlinks: VaultParser.notesLinkingTo(note, notes),
        ),
    ];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}
