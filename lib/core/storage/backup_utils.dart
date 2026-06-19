import 'dart:convert';

class BackupPreview {
  final int markdownFilesCount;
  final int snippetsCount;
  final int apiHistoryCount;
  final int environmentsCount;
  final int settingsCount;

  const BackupPreview({
    required this.markdownFilesCount,
    required this.snippetsCount,
    required this.apiHistoryCount,
    required this.environmentsCount,
    required this.settingsCount,
  });

  bool get isEmpty =>
      markdownFilesCount == 0 &&
      snippetsCount == 0 &&
      apiHistoryCount == 0 &&
      environmentsCount == 0 &&
      settingsCount == 0;
}

class BackupUtils {
  static const type = 'devdesk_backup';
  static const version = 1;
  static const settingsBox = 'settings';
  static const dashboardBox = 'dashboard';
  static const apiHistoryBox = 'api_history';
  static const apiEnvironmentsBox = 'api_environments';
  static const snippetsBox = 'snippets';
  static const markdownFilesBox = 'markdown_files';
  static const knownBoxes = <String>[
    settingsBox,
    dashboardBox,
    apiHistoryBox,
    apiEnvironmentsBox,
    snippetsBox,
    markdownFilesBox,
  ];

  static Map<String, dynamic> createDocument(Map<String, dynamic> boxes) {
    return {
      'type': type,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'boxes': boxes,
    };
  }

  static Map<String, dynamic> decodeBackupText(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('Backup root must be a JSON object.');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Backup must be valid JSON.');
    }
  }

  static Map<String, dynamic> extractBoxes(Map<String, dynamic> document) {
    final rawBoxes = document['type'] == type ? document['boxes'] : document;
    if (rawBoxes is! Map) {
      throw const FormatException('Backup "boxes" must be an object.');
    }
    final boxes = Map<String, dynamic>.from(rawBoxes);
    for (final entry in boxes.entries) {
      if (!knownBoxes.contains(entry.key)) continue;
      if (entry.value is! Map) {
        throw FormatException(
            'Backup section "${entry.key}" must be an object.');
      }
    }
    final hasKnownBox = knownBoxes.any(boxes.containsKey);
    if (!hasKnownBox) {
      throw const FormatException('Backup does not contain DevDesk data.');
    }
    return boxes;
  }

  static BackupPreview preview(Map<String, dynamic> document) {
    final boxes = extractBoxes(document);
    final markdown = _section(boxes, markdownFilesBox);
    final snippets = _section(boxes, snippetsBox);
    final apiHistory = _section(boxes, apiHistoryBox);
    final environments = _section(boxes, apiEnvironmentsBox);
    final settings = _section(boxes, settingsBox);
    return BackupPreview(
      markdownFilesCount: markdown.length,
      snippetsCount: snippets.length,
      apiHistoryCount: apiHistory.length,
      environmentsCount: _environmentCount(environments),
      settingsCount: settings.length,
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
}
