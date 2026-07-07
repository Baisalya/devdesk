import 'package:hive_flutter/hive_flutter.dart';

import 'backup_utils.dart';

/// Handles initialization of Hive and opening of boxes used throughout the
/// application. All data is stored locally on device. For complex
/// persistence requirements you can add new boxes here.
class LocalStorage {
  static bool _initialized = false;

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

  /// Initialize Hive and register adapters. Call this once at app startup.
  static Future<void> initialize({String? subDir}) async {
    if (_initialized) return;
    await Hive.initFlutter(subDir);
    _initialized = true;
  }

  /// Initializes Hive with an explicit filesystem path for tests.
  static void initializeForTest(String path) {
    if (_initialized) return;
    Hive.init(path);
    _initialized = true;
  }

  /// Opens a Hive box with the given [name]. Use generics to specify the
  /// value type. For example `Box<YourType>`.
  static Future<Box<T>> openBox<T>(String name) async {
    if (!_initialized) {
      await initialize();
    }
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  /// Deletes all boxes and data. Useful for clearing app data from
  /// Settings. Use with caution.
  static Future<void> clearAll() async {
    if (!_initialized) {
      await initialize();
    }
    for (final key in knownBoxes) {
      final box = await _openKnownBox(key);
      await box.clear();
    }
  }

  /// Exports all known local boxes into a JSON-safe map.
  static Future<Map<String, dynamic>> exportAll() async {
    if (!_initialized) {
      await initialize();
    }
    final export = <String, dynamic>{};
    for (final name in knownBoxes) {
      final box = await _openKnownBox(name);
      export[name] = box.toMap().map(
            (key, value) => MapEntry(key.toString(), _jsonSafeValue(value)),
          );
    }
    return export;
  }

  /// Exports all known local boxes wrapped in a versioned backup document.
  static Future<Map<String, dynamic>> exportBackupDocument() async {
    return BackupUtils.createDocument(await exportAll());
  }

  /// Imports a JSON-safe backup produced by [exportAll].
  static Future<void> importAll(
    Map<String, dynamic> data, {
    bool replace = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    final boxes = BackupUtils.extractBoxes(data);
    for (final name in knownBoxes) {
      if (!boxes.containsKey(name)) continue;
      final value = boxes[name];
      if (value is! Map) {
        throw FormatException('Backup section "$name" must be an object.');
      }
      final box = await _openKnownBox(name);
      if (replace) {
        await box.clear();
      }
      for (final entry in value.entries) {
        await box.put(_restoreKey(name, entry.key.toString()), entry.value);
      }
    }
  }

  static Future<Box> _openKnownBox(String name) {
    switch (name) {
      case apiHistoryBox:
      case apiWorkspacesBox:
      case apiWorkspaceHistoryBox:
      case apiWorkspaceReportsBox:
      case snippetsBox:
        return openBox<Map>(name);
      case markdownFilesBox:
        return openBox<String>(name);
      case vaultNotesBox:
        return openBox<Map>(name);
      case vaultMetadataBox:
        return openBox<dynamic>(name);
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
    if (value is Iterable) {
      return value.map(_jsonSafeValue).toList();
    }
    return value;
  }
}
