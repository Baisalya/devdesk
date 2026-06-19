import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/backup_utils.dart';
import 'package:devdesk/core/storage/local_storage.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_backup_test');
    LocalStorage.initializeForTest(dir.path);
  });

  test('export and import local backup structure', () async {
    await LocalStorage.clearAll();
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await settings.put('theme_mode', 'dark');

    final exported = await LocalStorage.exportAll();
    expect(exported, contains(LocalStorage.settingsBox));
    expect(exported[LocalStorage.settingsBox]['theme_mode'], 'dark');

    await settings.put('theme_mode', 'light');
    await LocalStorage.importAll(exported);

    expect(settings.get('theme_mode'), 'dark');
  });

  test('versioned backup document previews and imports', () async {
    await LocalStorage.clearAll();
    final markdown =
        await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
    await markdown.put('README.md', '# DevDesk');

    final document = await LocalStorage.exportBackupDocument();
    expect(document['type'], BackupUtils.type);

    final preview = BackupUtils.preview(document);
    expect(preview.markdownFilesCount, 1);

    await markdown.clear();
    await LocalStorage.importAll(document);
    expect(markdown.get('README.md'), '# DevDesk');
  });

  test('backup import can merge without clearing existing data', () async {
    await LocalStorage.clearAll();
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await settings.put('existing', true);

    await LocalStorage.importAll(
      {
        'type': BackupUtils.type,
        'boxes': {
          LocalStorage.settingsBox: {'theme_mode': 'dark'},
        },
      },
      replace: false,
    );

    expect(settings.get('existing'), isTrue);
    expect(settings.get('theme_mode'), 'dark');
  });

  test('invalid backup section throws FormatException', () async {
    expect(
      () => LocalStorage.importAll({LocalStorage.settingsBox: 'invalid'}),
      throwsA(isA<FormatException>()),
    );
  });
}
