import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/markdown/vault/model/vault_note.dart';
import 'package:devdesk/features/markdown/vault/provider/vault_export_service.dart';
import 'package:devdesk/features/markdown/vault/provider/vault_provider.dart';
import 'package:devdesk/features/markdown/vault/provider/vault_template_service.dart';
import 'package:devdesk/features/markdown/vault/utils/vault_parser.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_vault_test');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.vaultNotesBox);
    await box.clear();
  });

  group('VaultNote model', () {
    test('serializes and deserializes markdown file model', () {
      final note = VaultNote(
        title: 'Test Note',
        content: 'Content',
        folderPath: 'docs/api',
        tags: const ['test'],
        links: const ['Other'],
        isFavorite: true,
        isPinned: true,
        metadata: const {'status': 'draft'},
        versionHistory: [
          NoteVersion(timestamp: DateTime(2026), content: 'old'),
        ],
      );

      final fromMap = VaultNote.fromMap(note.toMap());

      expect(fromMap.id, note.id);
      expect(fromMap.fullPath, 'docs/api/Test Note');
      expect(fromMap.fileName, 'Test Note.md');
      expect(fromMap.tags, contains('test'));
      expect(fromMap.metadata['status'], 'draft');
      expect(fromMap.versionHistory.single.content, 'old');
    });
  });

  group('Vault provider CRUD', () {
    test('creates, renames, duplicates, moves and deletes notes', () async {
      final notifier = VaultNotesNotifier();
      await notifier.loadNotes();

      final note = await notifier.createNote(
        title: 'Alpha',
        folderPath: 'work/projects',
      );
      expect(notifier.state.single.folderPath, 'work/projects');

      await notifier.renameNote(note.id, 'Beta');
      expect(notifier.state.single.title, 'Beta');

      await notifier.moveNote(note.id, 'archive');
      expect(notifier.state.single.folderPath, 'archive');

      final duplicate = await notifier.duplicateNote(note.id);
      expect(duplicate, isNotNull);
      expect(notifier.state.map((note) => note.title), contains('Beta Copy'));

      await notifier.deleteNote(note.id);
      expect(notifier.state.length, 1);
      expect(notifier.state.single.title, 'Beta Copy');
    });

    test('generates backlinks and restores version history', () async {
      final notifier = VaultNotesNotifier();
      await notifier.loadNotes();

      final target = await notifier.createNote(title: 'Target');
      final source = await notifier.createNote(
        title: 'Source',
        content: 'See [[Target]]',
      );

      final updatedTarget =
          notifier.state.firstWhere((note) => note.id == target.id);
      expect(updatedTarget.backlinks, contains('Source'));

      await notifier.updateNoteContent(source.id, 'See [[Target]]\n\nChanged');
      final changedSource =
          notifier.state.firstWhere((note) => note.id == source.id);
      expect(changedSource.versionHistory.single.content, 'See [[Target]]');

      await notifier.restoreVersion(
        source.id,
        changedSource.versionHistory.single,
      );
      final restored =
          notifier.state.firstWhere((note) => note.id == source.id);
      expect(restored.content, 'See [[Target]]');
    });
  });

  group('VaultParser', () {
    test('extracts wiki links and detects broken internal links', () {
      final current = VaultNote(
        title: 'Current',
        content: 'See [[Existing]] and [[Missing|alias]].',
      );
      final existing = VaultNote(title: 'Existing', content: '');

      expect(VaultParser.extractWikiLinks(current.content), [
        'Existing',
        'Missing',
      ]);
      expect(VaultParser.brokenInternalLinks(current, [current, existing]), [
        'Missing',
      ]);
    });

    test('extracts inline and metadata tags', () {
      const text = '''---
tags: [flutter, devdesk]
---

# Heading
Body #markdown and #tools/dev
''';

      expect(VaultParser.extractAllTags(text), [
        'flutter',
        'devdesk',
        'markdown',
        'tools/dev',
      ]);
    });

    test('parses frontmatter metadata', () {
      const text = '''---
title: DevDesk
status: draft
tags:
- vault
- android
---

# Body
''';

      final frontmatter = VaultParser.parseFrontmatter(text);

      expect(frontmatter.metadata['title'], 'DevDesk');
      expect(frontmatter.metadata['status'], 'draft');
      expect(frontmatter.metadata['tags'], ['vault', 'android']);
      expect(frontmatter.body.trim(), '# Body');
    });

    test('extracts outline and generates table of contents', () {
      const text = '# Title\n\n## Install\n\n```dart\n# ignored\n```\n### Run';

      final outline = VaultParser.extractHeadings(text);
      final toc = VaultParser.generateTableOfContents(text);

      expect(outline.map((heading) => heading.text), [
        'Title',
        'Install',
        'Run',
      ]);
      expect(toc, contains('- [Title](#title)'));
      expect(toc, contains('  - [Install](#install)'));
      expect(toc, contains('    - [Run](#run)'));
      expect(toc, isNot(contains('ignored')));
    });

    test('detects and masks secrets', () {
      const text = 'API_KEY=abc12345\nAuthorization: Bearer qwerty123';

      expect(VaultParser.containsSecrets(text), isTrue);
      expect(VaultParser.maskSecrets(text), isNot(contains('abc12345')));
      expect(VaultParser.maskSecrets(text), contains('[masked]'));
    });
  });

  group('Templates and export/import', () {
    test('generates markdown templates', () {
      expect(VaultTemplateService.templates.keys, contains('README'));
      expect(VaultTemplateService.templates.keys, contains('Changelog'));
      expect(VaultTemplateService.templates.keys, contains('Privacy Policy'));
      expect(VaultTemplateService.dailyNote(DateTime(2026, 6, 20)),
          contains('# 2026-06-20'));
      expect(
        VaultTemplateService.apiDocsFromRequest(
          name: 'Users API',
          method: 'POST',
          url: '/users',
        ),
        contains('`POST /users`'),
      );
    });

    test('validates JSON and ZIP backup round trips', () {
      final notes = [
        VaultNote(
          title: 'README',
          folderPath: 'docs',
          content: '# README\n\n#tag\n[[API]]',
        ),
        VaultNote(title: 'API', content: '# API'),
      ];

      final jsonBackup = jsonEncode(VaultExportService.buildBackupJson(notes));
      final fromJson = VaultExportService.parseBackupJson(jsonBackup);
      expect(fromJson.length, 2);
      expect(fromJson.first.title, 'README');

      final zip = VaultExportService.buildZipBytes(notes);
      final fromZip = VaultExportService.importZipBytes(zip);
      expect(fromZip.map((note) => note.fullPath), contains('docs/README'));
      expect(fromZip.first.tags, contains('tag'));
      expect(fromZip.first.links, contains('API'));
    });

    test('rejects unsafe vault ZIP paths', () {
      final archive = Archive()
        ..addFile(ArchiveFile('../evil.md', 4, utf8.encode('nope')));
      final bytes = ZipEncoder().encode(archive);

      expect(
        () => VaultExportService.importZipBytes(bytes),
        throwsFormatException,
      );
    });
  });
}
