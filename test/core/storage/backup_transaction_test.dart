import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/backup_utils.dart';
import 'package:devdesk/core/storage/local_storage.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('devdesk_storage_tx_');
    LocalStorage.initializeForTest(directory.path);
  });

  setUp(() async {
    LocalStorage.debugFaultInjector = null;
    await LocalStorage.clearAll();
  });

  tearDownAll(() async {
    LocalStorage.debugFaultInjector = null;
    await LocalStorage.closeAll();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('startup storage failure enters recovery without mutating data',
      () async {
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await settings.put('theme_mode', 'dark');
    LocalStorage.debugFaultInjector = (phase, boxName, mutationIndex) {
      if (phase == 'bootstrap_before_open' &&
          boxName == LocalStorage.apiWorkspacesBox) {
        throw FileSystemException('deterministic startup open failure');
      }
    };

    final result = await LocalStorage.bootstrap();
    expect(result.isReady, isFalse);
    expect(result.canReset, isTrue);
    expect(settings.get('theme_mode'), 'dark');
  });

  test('future backup version is rejected before any mutation', () async {
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await settings.put('theme_mode', 'dark');
    final futureBackup = {
      'type': BackupUtils.type,
      'version': BackupUtils.version + 1,
      'boxes': {
        LocalStorage.settingsBox: {'theme_mode': 'light'},
      },
    };

    await expectLater(
      LocalStorage.importAll(futureBackup),
      throwsA(isA<FormatException>()),
    );
    expect(settings.get('theme_mode'), 'dark');
  });

  test('partial import failure restores exact pre-import snapshot', () async {
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    final markdown =
        await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
    await settings.put('theme_mode', 'dark');
    await settings.put('existing', true);
    await markdown.put('README.md', '# Original');
    LocalStorage.debugFaultInjector = (phase, boxName, mutationIndex) {
      if (phase == 'after_put' && mutationIndex == 2) {
        throw StateError('deterministic import failure');
      }
    };

    final backup = BackupUtils.createDocument({
      LocalStorage.settingsBox: {'theme_mode': 'light', 'new': true},
      LocalStorage.markdownFilesBox: {'README.md': '# Imported'},
    });
    try {
      await LocalStorage.importAll(backup);
      fail('The injected import failure was not raised.');
    } on BackupImportException catch (error) {
      expect(
        error.rollbackSucceeded,
        isTrue,
        reason: 'Rollback failed internally: ${error.rollbackCause}',
      );
    }

    expect(settings.toMap(), {'theme_mode': 'dark', 'existing': true});
    expect(markdown.toMap(), {'README.md': '# Original'});
  });

  test('startup recovers a persisted interrupted-import journal', () async {
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    final rollback =
        await LocalStorage.openBox<Map>(LocalStorage.importRollbackBox);
    final meta =
        await LocalStorage.openBox<dynamic>(LocalStorage.storageMetaBox);
    await settings.put('theme_mode', 'damaged');
    await rollback.put(LocalStorage.settingsBox, {'theme_mode': 'dark'});
    await meta.put('import_in_progress', {
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'boxes': [LocalStorage.settingsBox],
      'replace': true,
    });

    final result = await LocalStorage.bootstrap();
    expect(result.isReady, isTrue);
    expect(settings.get('theme_mode'), 'dark');
    expect(meta.get('import_in_progress'), isNull);
    expect(rollback.isEmpty, isTrue);
  });

  test('interrupted migration journal resumes safely on retry', () async {
    final meta =
        await LocalStorage.openBox<dynamic>(LocalStorage.storageMetaBox);
    await meta.put('storage_schema_version', 0);
    LocalStorage.debugFaultInjector = (phase, boxName, mutationIndex) {
      if (phase == 'migration_after_step' && mutationIndex == 1) {
        throw StateError('migration interrupted');
      }
    };

    final failed = await LocalStorage.bootstrap();
    expect(failed.isReady, isFalse);
    LocalStorage.debugFaultInjector = null;
    final recovered = await LocalStorage.bootstrap();
    expect(recovered.isReady, isTrue);
    expect(
      meta.get('storage_schema_version'),
      LocalStorage.currentSchemaVersion,
    );
    expect(meta.get('migration_in_progress'), isNull);
  });

  test('startup rejects storage created by a future app version', () async {
    final meta =
        await LocalStorage.openBox<dynamic>(LocalStorage.storageMetaBox);
    await meta.put(
      'storage_schema_version',
      LocalStorage.currentSchemaVersion + 1,
    );
    final result = await LocalStorage.bootstrap();
    expect(result.isReady, isFalse);
    expect(result.message, contains('newer DevDesk storage format'));
  });

  test('backup depth and record limits are enforced before mutation', () {
    dynamic deep = 'value';
    for (var index = 0; index < BackupUtils.maxNestingDepth + 2; index++) {
      deep = {'child': deep};
    }
    final document = BackupUtils.createDocument({
      LocalStorage.settingsBox: {'deep': deep},
    });
    expect(
      () => BackupUtils.validateDocument(document),
      throwsA(isA<FormatException>()),
    );
  });
}
