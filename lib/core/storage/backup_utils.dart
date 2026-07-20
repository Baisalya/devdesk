import 'dart:convert';

class BackupPreview {
  final int markdownFilesCount;
  final int snippetsCount;
  final int apiHistoryCount;
  final int environmentsCount;
  final int apiWorkspacesCount;
  final int apiWorkspaceHistoryCount;
  final int apiWorkspaceReportsCount;
  final int settingsCount;
  final int vaultNotesCount;
  final int vaultMetadataCount;
  final int totalRecords;
  final bool isLegacy;

  const BackupPreview({
    required this.markdownFilesCount,
    required this.snippetsCount,
    required this.apiHistoryCount,
    required this.environmentsCount,
    this.apiWorkspacesCount = 0,
    this.apiWorkspaceHistoryCount = 0,
    this.apiWorkspaceReportsCount = 0,
    required this.settingsCount,
    this.vaultNotesCount = 0,
    this.vaultMetadataCount = 0,
    this.totalRecords = 0,
    this.isLegacy = false,
  });

  int get computedTotalRecords => totalRecords > 0
      ? totalRecords
      : markdownFilesCount +
          snippetsCount +
          apiHistoryCount +
          environmentsCount +
          apiWorkspacesCount +
          apiWorkspaceHistoryCount +
          apiWorkspaceReportsCount +
          settingsCount +
          vaultNotesCount +
          vaultMetadataCount;

  bool get isEmpty => computedTotalRecords == 0;
}

class BackupValidationResult {
  final int version;
  final bool legacy;
  final Map<String, dynamic> boxes;
  final int totalRecords;

  const BackupValidationResult({
    required this.version,
    required this.legacy,
    required this.boxes,
    required this.totalRecords,
  });
}

class BackupUtils {
  static const type = 'devdesk_backup';
  static const version = 2;
  static const minimumSupportedVersion = 1;
  static const appVersion = '1.0.0+1';

  static const maxBackupTextBytes = 20 * 1024 * 1024;
  static const maxTotalRecords = 10000;
  static const maxRecordsPerSection = 5000;
  static const maxStringBytes = 5 * 1024 * 1024;
  static const maxNestingDepth = 64;
  static const maxCollectionItems = 20000;

  static const settingsBox = 'settings';
  static const dashboardBox = 'dashboard';
  static const apiHistoryBox = 'api_history';
  static const apiEnvironmentsBox = 'api_environments';
  static const apiWorkspacesBox = 'api_workspaces';
  static const apiWorkspaceHistoryBox = 'api_workspace_history';
  static const apiWorkspaceReportsBox = 'api_workspace_reports';
  static const snippetsBox = 'snippets';
  static const apiWorkspaceMetaBox = 'api_workspace_meta';
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

  static const schemaVersions = <String, int>{
    settingsBox: 1,
    dashboardBox: 1,
    apiHistoryBox: 1,
    apiEnvironmentsBox: 1,
    apiWorkspacesBox: 2,
    apiWorkspaceHistoryBox: 2,
    apiWorkspaceReportsBox: 2,
    apiWorkspaceMetaBox: 1,
    snippetsBox: 1,
    markdownFilesBox: 1,
    vaultNotesBox: 1,
    vaultMetadataBox: 1,
  };

  static Map<String, dynamic> createDocument(
    Map<String, dynamic> boxes, {
    DateTime? exportedAt,
  }) {
    final safeBoxes = <String, dynamic>{
      for (final name in knownBoxes)
        if (boxes[name] is Map) name: boxes[name],
    };
    return {
      'type': type,
      'version': version,
      'appVersion': appVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'schemaVersions': schemaVersions,
      'secretsIncluded': false,
      'boxes': safeBoxes,
    };
  }

  static Map<String, dynamic> decodeBackupText(String text) {
    if (utf8.encode(text).length > maxBackupTextBytes) {
      throw const FormatException('Backup file is larger than the safe limit.');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('Backup root must be a JSON object.');
      }
      final document = Map<String, dynamic>.from(decoded);
      validateDocument(document);
      return document;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Backup must be valid JSON.');
    }
  }

  static BackupValidationResult validateDocument(
    Map<String, dynamic> document,
  ) {
    final wrapped =
        document.containsKey('type') || document.containsKey('boxes');
    if (wrapped && document['type'] != type) {
      throw const FormatException('Unsupported backup type.');
    }

    final legacy = !wrapped;
    final rawVersion = legacy ? minimumSupportedVersion : document['version'];
    final backupVersion =
        rawVersion is int ? rawVersion : minimumSupportedVersion;
    if (backupVersion > version) {
      throw FormatException(
        'This backup was created by a newer DevDesk data format (version $backupVersion).',
      );
    }
    if (backupVersion < minimumSupportedVersion) {
      throw FormatException('Unsupported backup version $backupVersion.');
    }
    if (!legacy && document['secretsIncluded'] == true) {
      throw const FormatException(
        'Backups containing secret values are not accepted. Export without secrets.',
      );
    }
    final declaredSchemas = document['schemaVersions'];
    if (!legacy && declaredSchemas != null && declaredSchemas is! Map) {
      throw const FormatException('Backup schemaVersions must be an object.');
    }
    if (declaredSchemas is Map) {
      for (final entry in declaredSchemas.entries) {
        final name = entry.key.toString();
        if (!schemaVersions.containsKey(name)) continue;
        final declared = entry.value;
        if (declared is! int || declared < 1) {
          throw FormatException(
              'Backup schema version for "$name" is invalid.');
        }
        if (declared > schemaVersions[name]!) {
          throw FormatException(
            'Backup section "$name" uses a newer schema version.',
          );
        }
      }
    }

    final rawBoxes = wrapped ? document['boxes'] : document;
    if (rawBoxes is! Map) {
      throw const FormatException('Backup "boxes" must be an object.');
    }
    final boxes = Map<String, dynamic>.from(rawBoxes);
    var totalRecords = 0;
    var hasKnownBox = false;
    for (final entry in boxes.entries) {
      if (!knownBoxes.contains(entry.key)) continue;
      hasKnownBox = true;
      if (entry.value is! Map) {
        throw FormatException(
          'Backup section "${entry.key}" must be an object.',
        );
      }
      final section = Map<dynamic, dynamic>.from(entry.value as Map);
      if (section.length > maxRecordsPerSection) {
        throw FormatException(
          'Backup section "${entry.key}" contains too many records.',
        );
      }
      for (final record in section.entries) {
        _validateRecord(entry.key, record.key, record.value);
      }
      totalRecords += section.length;
      if (totalRecords > maxTotalRecords) {
        throw const FormatException('Backup contains too many records.');
      }
      _validateValue(section, depth: 0, itemBudget: maxCollectionItems);
    }
    if (!hasKnownBox) {
      throw const FormatException('Backup does not contain DevDesk data.');
    }
    return BackupValidationResult(
      version: backupVersion,
      legacy: legacy || backupVersion < version,
      boxes: boxes,
      totalRecords: totalRecords,
    );
  }

  static Map<String, dynamic> extractBoxes(Map<String, dynamic> document) {
    return validateDocument(document).boxes;
  }

  static BackupPreview preview(Map<String, dynamic> document) {
    final validation = validateDocument(document);
    final boxes = validation.boxes;
    final markdown = _section(boxes, markdownFilesBox);
    final snippets = _section(boxes, snippetsBox);
    final apiHistory = _section(boxes, apiHistoryBox);
    final environments = _section(boxes, apiEnvironmentsBox);
    final apiWorkspaces = _section(boxes, apiWorkspacesBox);
    final apiWorkspaceHistory = _section(boxes, apiWorkspaceHistoryBox);
    final apiWorkspaceReports = _section(boxes, apiWorkspaceReportsBox);
    final settings = _section(boxes, settingsBox);
    final vaultNotes = _section(boxes, vaultNotesBox);
    final vaultMetadata = _section(boxes, vaultMetadataBox);
    return BackupPreview(
      markdownFilesCount: markdown.length,
      snippetsCount: snippets.length,
      apiHistoryCount: apiHistory.length,
      environmentsCount: _environmentCount(environments),
      apiWorkspacesCount: apiWorkspaces.length,
      apiWorkspaceHistoryCount: apiWorkspaceHistory.length,
      apiWorkspaceReportsCount: apiWorkspaceReports.length,
      settingsCount: settings.length,
      vaultNotesCount: vaultNotes.length,
      vaultMetadataCount: vaultMetadata.length,
      totalRecords: validation.totalRecords,
      isLegacy: validation.legacy,
    );
  }

  static Map<String, dynamic> _section(
    Map<String, dynamic> boxes,
    String name,
  ) {
    final value = boxes[name];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static int _environmentCount(Map<String, dynamic> section) {
    final items = section['items'];
    if (items is Map) return items.length;
    return section.length;
  }

  static void _validateRecord(
    String sectionName,
    dynamic recordKey,
    dynamic recordValue,
  ) {
    final key = recordKey.toString();
    if (key.isEmpty || utf8.encode(key).length > 1024) {
      throw FormatException(
          'Backup section "$sectionName" has an invalid key.');
    }
    if (sectionName == markdownFilesBox && recordValue is! String) {
      throw const FormatException('Markdown backup records must contain text.');
    }
    const mapRecordSections = <String>{
      apiHistoryBox,
      apiWorkspacesBox,
      apiWorkspaceHistoryBox,
      apiWorkspaceReportsBox,
      snippetsBox,
      vaultNotesBox,
    };
    if (mapRecordSections.contains(sectionName) && recordValue is! Map) {
      throw FormatException(
        'Backup section "$sectionName" contains an invalid record.',
      );
    }
  }

  static int _validateValue(
    dynamic value, {
    required int depth,
    required int itemBudget,
  }) {
    if (depth > maxNestingDepth) {
      throw const FormatException('Backup data is nested too deeply.');
    }
    if (value is String) {
      if (utf8.encode(value).length > maxStringBytes) {
        throw const FormatException('Backup contains an oversized text value.');
      }
      return itemBudget;
    }
    if (value is Map) {
      if (value.length > itemBudget) {
        throw const FormatException('Backup contains too many nested items.');
      }
      var remaining = itemBudget - value.length;
      for (final entry in value.entries) {
        remaining = _validateValue(
          entry.key.toString(),
          depth: depth + 1,
          itemBudget: remaining,
        );
        remaining = _validateValue(
          entry.value,
          depth: depth + 1,
          itemBudget: remaining,
        );
      }
      return remaining;
    }
    if (value is Iterable) {
      final items = value.toList(growable: false);
      if (items.length > itemBudget) {
        throw const FormatException('Backup contains too many nested items.');
      }
      var remaining = itemBudget - items.length;
      for (final item in items) {
        remaining = _validateValue(
          item,
          depth: depth + 1,
          itemBudget: remaining,
        );
      }
      return remaining;
    }
    if (value == null || value is num || value is bool) return itemBudget;
    throw const FormatException('Backup contains an unsupported value type.');
  }
}
