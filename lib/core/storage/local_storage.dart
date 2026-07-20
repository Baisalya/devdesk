import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../security/data_redactor.dart';
import '../security/secure_secret_store.dart';
import 'backup_utils.dart';

enum StorageBootstrapStatus { ready, recoveryRequired }

class StorageBootstrapResult {
  final StorageBootstrapStatus status;
  final String? message;
  final bool canReset;

  const StorageBootstrapResult._(
    this.status, {
    this.message,
    this.canReset = true,
  });

  const StorageBootstrapResult.ready()
      : this._(StorageBootstrapStatus.ready, canReset: false);

  const StorageBootstrapResult.recovery(String message)
      : this._(StorageBootstrapStatus.recoveryRequired, message: message);

  bool get isReady => status == StorageBootstrapStatus.ready;
}

typedef StorageFaultInjector = FutureOr<void> Function(
  String phase,
  String boxName,
  int mutationIndex,
);

class BackupImportException implements Exception {
  final String message;
  final Object cause;
  final bool rollbackSucceeded;
  final Object? rollbackCause;

  const BackupImportException(
    this.message, {
    required this.cause,
    required this.rollbackSucceeded,
    this.rollbackCause,
  });

  @override
  String toString() => message;
}

/// Owns the application-level Hive lifecycle, schema version, backup boundary,
/// quarantine, and destructive reset coordination.
class LocalStorage {
  static bool _initialized = false;
  static bool _clearing = false;

  static const currentSchemaVersion = 2;
  static const _schemaVersionKey = 'storage_schema_version';

  static const settingsBox = 'settings';
  static const dashboardBox = 'dashboard';
  static const apiHistoryBox = 'api_history';
  static const apiEnvironmentsBox = 'api_environments';
  static const apiWorkspacesBox = 'api_workspaces';
  static const apiWorkspaceHistoryBox = 'api_workspace_history';
  static const apiWorkspaceReportsBox = 'api_workspace_reports';
  static const apiWorkspaceMetaBox = 'api_workspace_meta';
  static const snippetsBox = 'snippets';
  static const markdownFilesBox = 'markdown_files';
  static const vaultNotesBox = 'vault_notes';
  static const vaultMetadataBox = 'vault_metadata';
  static const storageMetaBox = 'storage_meta';
  static const quarantineBox = 'storage_quarantine';
  static const importRollbackBox = 'storage_import_rollback';

  static const knownBoxes = <String>[
    settingsBox,
    dashboardBox,
    apiHistoryBox,
    apiEnvironmentsBox,
    apiWorkspacesBox,
    apiWorkspaceHistoryBox,
    apiWorkspaceReportsBox,
    apiWorkspaceMetaBox,
    snippetsBox,
    markdownFilesBox,
    vaultNotesBox,
    vaultMetadataBox,
  ];

  static const internalBoxes = <String>[
    storageMetaBox,
    quarantineBox,
    importRollbackBox,
  ];

  /// Optional deterministic fault injection used only by regression tests.
  static StorageFaultInjector? debugFaultInjector;

  static Future<void> initialize({String? subDir}) async {
    if (_initialized) return;
    await Hive.initFlutter(subDir);
    _initialized = true;
  }

  static void initializeForTest(String path) {
    if (_initialized) return;
    Hive.init(path);
    _initialized = true;
  }

  static Future<StorageBootstrapResult> bootstrap({String? subDir}) async {
    try {
      await initialize(subDir: subDir);
      final meta = await openBox<dynamic>(storageMetaBox);
      final rawVersion = meta.get(_schemaVersionKey);
      final storedVersion = rawVersion is int ? rawVersion : 0;
      if (storedVersion > currentSchemaVersion) {
        return StorageBootstrapResult.recovery(
          'This data was created by a newer DevDesk storage format. Update DevDesk before opening it.',
        );
      }
      for (final name in knownBoxes) {
        await _injectFault('bootstrap_before_open', name, 0);
        await _openKnownBox(name);
      }
      await openBox<Map>(quarantineBox);
      await openBox<Map>(importRollbackBox);
      await _recoverInterruptedImport(meta);
      final effectiveVersion = await _recoverMigrationJournal(
        meta,
        storedVersion,
      );
      if (effectiveVersion < currentSchemaVersion) {
        await _migrate(meta, fromVersion: effectiveVersion);
      }
      return const StorageBootstrapResult.ready();
    } catch (error) {
      return StorageBootstrapResult.recovery(
        'Local data could not be opened safely. You can retry or reset local data.',
      );
    }
  }

  static Future<Box<T>> openBox<T>(String name) async {
    if (_clearing) {
      throw StateError(
          'Local data is being cleared. Try again when it finishes.');
    }
    if (!_initialized) await initialize();
    if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
    return Hive.openBox<T>(name);
  }

  static Future<void> clearAll() async {
    if (_clearing) return;
    if (!_initialized) await initialize();
    final boxes = <String, Box>{};
    for (final key in [...knownBoxes, ...internalBoxes]) {
      boxes[key] = await _openKnownBox(key);
    }
    _clearing = true;
    try {
      for (final box in boxes.values) {
        await box.clear();
      }
      await SecureSecretStore.clearAll();
      await boxes[storageMetaBox]!.put(_schemaVersionKey, currentSchemaVersion);
    } finally {
      _clearing = false;
    }
  }

  /// Exports ordinary application records. Protected secret values are never
  /// read from the platform vault and conservative redaction is applied to all
  /// portable sinks by default.
  static Future<Map<String, dynamic>> exportAll({bool redact = true}) async {
    if (!_initialized) await initialize();
    final export = <String, dynamic>{};
    for (final name in knownBoxes) {
      final box = await _openKnownBox(name);
      final section = box.toMap().map(
            (key, value) => MapEntry(key.toString(), _jsonSafeValue(value)),
          );
      export[name] = redact ? DataRedactor.deepRedact(section) : section;
    }
    return export;
  }

  static Future<Map<String, dynamic>> exportBackupDocument() async {
    return BackupUtils.createDocument(await exportAll());
  }

  /// Validates and stages the complete import before mutation. Any failure after
  /// the first mutation restores every affected box to its exact snapshot.
  static Future<void> importAll(
    Map<String, dynamic> data, {
    bool replace = true,
  }) async {
    if (!_initialized) await initialize();
    final validation = BackupUtils.validateDocument(data);
    final staged = <String, Map<dynamic, dynamic>>{};
    for (final name in knownBoxes) {
      final raw = validation.boxes[name];
      if (raw is! Map) continue;
      final safe = DataRedactor.deepRedact(raw);
      final section = Map<dynamic, dynamic>.from(safe as Map);
      staged[name] = {
        for (final entry in section.entries)
          _restoreKey(name, entry.key.toString()): entry.value,
      };
    }
    if (staged.isEmpty) {
      throw const FormatException('Backup does not contain importable data.');
    }

    final snapshots = <String, Map<dynamic, dynamic>>{};
    for (final name in staged.keys) {
      final box = await _openKnownBox(name);
      snapshots[name] = Map<dynamic, dynamic>.from(box.toMap());
    }

    final meta = await openBox<dynamic>(storageMetaBox);
    final rollbackBox = await openBox<Map>(importRollbackBox);
    await rollbackBox.clear();
    for (final entry in snapshots.entries) {
      await rollbackBox.put(entry.key, entry.value);
    }
    await meta.put('import_in_progress', {
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'boxes': staged.keys.toList(growable: false),
      'replace': replace,
    });

    var mutationIndex = 0;
    var mutationStarted = false;
    try {
      await _injectFault('validated', '', mutationIndex);
      for (final entry in staged.entries) {
        final box = await _openKnownBox(entry.key);
        await _injectFault('before_section', entry.key, mutationIndex);
        if (replace) {
          mutationStarted = true;
          await box.clear();
          mutationIndex++;
          await _injectFault('after_clear', entry.key, mutationIndex);
        }
        for (final record in entry.value.entries) {
          mutationStarted = true;
          await box.put(record.key, record.value);
          mutationIndex++;
          await _injectFault('after_put', entry.key, mutationIndex);
        }
      }
      await _verifyImport(staged, replace: replace, snapshots: snapshots);
      await _injectFault('verified', '', mutationIndex);
      await rollbackBox.clear();
      await meta.delete('import_in_progress');
    } catch (error) {
      if (!mutationStarted) {
        await rollbackBox.clear();
        await meta.delete('import_in_progress');
        rethrow;
      }
      var rollbackSucceeded = true;
      Object? rollbackCause;
      try {
        for (final entry in snapshots.entries) {
          final box = await _openKnownBox(entry.key);
          await box.clear();
          for (final record in entry.value.entries) {
            await box.put(record.key, record.value);
          }
        }
        await _verifySnapshots(snapshots);
        await rollbackBox.clear();
        await meta.delete('import_in_progress');
      } catch (error) {
        rollbackSucceeded = false;
        rollbackCause = error;
      }
      throw BackupImportException(
        rollbackSucceeded
            ? 'Backup import failed. Existing local data was restored.'
            : 'Backup import failed and automatic recovery could not be verified.',
        cause: error,
        rollbackSucceeded: rollbackSucceeded,
        rollbackCause: rollbackCause,
      );
    }
  }

  static Future<void> quarantineRecord({
    required String boxName,
    required String recordKey,
    required dynamic value,
  }) async {
    final quarantine = await openBox<Map>(quarantineBox);
    final safe = DataRedactor.deepRedact(_jsonSafeValue(value));
    final quarantineKey =
        '$boxName:$recordKey:${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await quarantine.put(quarantineKey, {
      'box': boxName,
      'recordKey': recordKey,
      'quarantinedAt': DateTime.now().toUtc().toIso8601String(),
      'value': safe,
    });
    if (knownBoxes.contains(boxName)) {
      final source = await _openKnownBox(boxName);
      await source.delete(_restoreKey(boxName, recordKey));
    }
  }

  static Future<void> destructiveReset() async {
    if (!_initialized) await initialize();
    for (final name in [...knownBoxes, ...internalBoxes]) {
      try {
        if (Hive.isBoxOpen(name)) await Hive.box(name).close();
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // Continue so one damaged box does not block removal of the others.
      }
    }
    await SecureSecretStore.clearAll();
    final meta = await openBox<dynamic>(storageMetaBox);
    await meta.put(_schemaVersionKey, currentSchemaVersion);
  }

  static Future<void> closeAll() async {
    if (!_initialized) return;
    await Hive.close();
    _initialized = false;
    _clearing = false;
  }

  static Future<void> _recoverInterruptedImport(Box<dynamic> meta) async {
    final journal = meta.get('import_in_progress');
    if (journal == null) return;
    if (journal is! Map || journal['boxes'] is! List) {
      throw StateError('The backup recovery journal is damaged.');
    }
    final rollback = await openBox<Map>(importRollbackBox);
    final names = (journal['boxes'] as List).whereType<String>().toList();
    if (names.isEmpty) {
      throw StateError('The backup recovery journal is incomplete.');
    }
    final snapshots = <String, Map<dynamic, dynamic>>{};
    for (final name in names) {
      if (!knownBoxes.contains(name)) {
        throw StateError(
            'The backup recovery journal names an unknown section.');
      }
      final raw = rollback.get(name);
      if (raw is! Map) {
        throw StateError('A backup rollback snapshot is missing.');
      }
      snapshots[name] = {
        for (final entry in raw.entries)
          _restoreKey(name, entry.key.toString()): entry.value,
      };
    }
    for (final entry in snapshots.entries) {
      final box = await _openKnownBox(entry.key);
      await box.clear();
      for (final record in entry.value.entries) {
        await box.put(record.key, record.value);
      }
    }
    await _verifySnapshots(snapshots);
    await rollback.clear();
    await meta.delete('import_in_progress');
  }

  static Future<int> _recoverMigrationJournal(
    Box<dynamic> meta,
    int storedVersion,
  ) async {
    final journal = meta.get('migration_in_progress');
    if (journal == null) return storedVersion;
    if (journal is! Map) {
      throw StateError('The storage migration journal is damaged.');
    }
    final from = journal['from'];
    final to = journal['to'];
    if (from is! int || to is! int || to != from + 1) {
      throw StateError('The storage migration journal is invalid.');
    }
    if (to > currentSchemaVersion) {
      throw StateError('A newer DevDesk version started this migration.');
    }
    if (storedVersion >= to) {
      await meta.delete('migration_in_progress');
      return storedVersion;
    }
    return from < storedVersion ? from : storedVersion;
  }

  static Future<void> _migrate(
    Box<dynamic> meta, {
    required int fromVersion,
  }) async {
    var version = fromVersion;
    while (version < currentSchemaVersion) {
      final next = version + 1;
      await meta.put('migration_in_progress', {
        'from': version,
        'to': next,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _injectFault('migration_before_step', storageMetaBox, next);
      // Versions 1 and 2 establish the registry and protected-secret boundary.
      // Feature-specific legacy secret migration occurs atomically when API
      // workspaces are first loaded because it requires the typed model.
      await meta.put(_schemaVersionKey, next);
      await _injectFault('migration_after_step', storageMetaBox, next);
      await meta.delete('migration_in_progress');
      version = next;
    }
  }

  static Future<Box> _openKnownBox(String name) {
    switch (name) {
      case apiHistoryBox:
      case apiWorkspacesBox:
      case apiWorkspaceHistoryBox:
      case apiWorkspaceReportsBox:
      case snippetsBox:
      case vaultNotesBox:
      case quarantineBox:
      case importRollbackBox:
        return openBox<Map>(name);
      case markdownFilesBox:
        return openBox<String>(name);
      default:
        return openBox<dynamic>(name);
    }
  }

  static dynamic _restoreKey(String boxName, String key) {
    if (boxName == snippetsBox || boxName == apiHistoryBox) {
      return int.tryParse(key) ?? key;
    }
    return key;
  }

  static dynamic _jsonSafeValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _jsonSafeValue(mapValue)),
      );
    }
    if (value is Iterable) return value.map(_jsonSafeValue).toList();
    return value;
  }

  static Future<void> _verifyImport(
    Map<String, Map<dynamic, dynamic>> staged, {
    required bool replace,
    required Map<String, Map<dynamic, dynamic>> snapshots,
  }) async {
    for (final entry in staged.entries) {
      final box = await _openKnownBox(entry.key);
      final expected = replace
          ? entry.value
          : <dynamic, dynamic>{...snapshots[entry.key]!, ...entry.value};
      if (_stableJson(box.toMap()) != _stableJson(expected)) {
        throw StateError('Imported data could not be verified.');
      }
    }
  }

  static Future<void> _verifySnapshots(
    Map<String, Map<dynamic, dynamic>> snapshots,
  ) async {
    for (final entry in snapshots.entries) {
      final box = await _openKnownBox(entry.key);
      if (_stableJson(box.toMap()) != _stableJson(entry.value)) {
        throw StateError('Rollback snapshot verification failed.');
      }
    }
  }

  static String _stableJson(Map<dynamic, dynamic> value) {
    dynamic normalize(dynamic input) {
      if (input is Map) {
        final entries = input.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        return {
          for (final entry in entries)
            entry.key.toString(): normalize(entry.value),
        };
      }
      if (input is Iterable) return input.map(normalize).toList();
      return input;
    }

    return jsonEncode(normalize(value));
  }

  static Future<void> _injectFault(
    String phase,
    String boxName,
    int mutationIndex,
  ) async {
    final injector = debugFaultInjector;
    if (injector != null) await injector(phase, boxName, mutationIndex);
  }
}
