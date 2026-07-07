import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../../../../core/files/external_file_service.dart';
import '../model/vault_note.dart';
import '../utils/vault_parser.dart';

class VaultExportService {
  static const backupType = 'devdesk_markdown_vault_backup';
  static const backupVersion = 1;
  static const maxImportFileBytes = 5 * 1024 * 1024;
  static const maxImportTotalBytes = 25 * 1024 * 1024;

  static Future<String?> exportVaultAsZip(List<VaultNote> notes) async {
    return ExternalFileService.saveBytesAs(
      suggestedName: 'devdesk_vault_backup.zip',
      bytes: buildZipBytes(notes),
      allowedExtensions: const ['zip'],
      dialogTitle: 'Export Vault as ZIP',
    );
  }

  static Future<String?> exportVaultAsJson(List<VaultNote> notes) {
    return ExternalFileService.saveTextAs(
      suggestedName: 'devdesk_vault_backup.json',
      content:
          const JsonEncoder.withIndent('  ').convert(buildBackupJson(notes)),
      allowedExtensions: const ['json'],
      dialogTitle: 'Export Vault as JSON',
    );
  }

  static Uint8List buildZipBytes(List<VaultNote> notes) {
    final archive = Archive();
    for (final note in notes) {
      final bytes = utf8.encode(note.content);
      archive.addFile(ArchiveFile(_archivePathFor(note), bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Could not encode vault ZIP archive.');
    }
    return Uint8List.fromList(encoded);
  }

  static List<VaultNote> importZipBytes(List<int> bytes) {
    if (bytes.length > maxImportTotalBytes) {
      throw const FormatException('Vault ZIP is larger than the safe limit.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    var totalBytes = 0;
    final notes = <VaultNote>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final path = file.name.replaceAll('\\', '/');
      if (!_isSafeArchivePath(path)) {
        throw FormatException('Unsafe path in ZIP: $path');
      }
      final lower = path.toLowerCase();
      if (!lower.endsWith('.md') && !lower.endsWith('.markdown')) continue;
      if (file.size > maxImportFileBytes) {
        throw FormatException('Markdown file is too large: $path');
      }
      totalBytes += file.size;
      if (totalBytes > maxImportTotalBytes) {
        throw const FormatException('Vault ZIP expands beyond the safe limit.');
      }
      final content = utf8.decode(List<int>.from(file.content as List));
      final parts = path.split('/');
      final fileName = parts.removeLast();
      final title = _titleFromFileName(fileName);
      notes.add(
        VaultNote(
          title: title,
          content: content,
          folderPath: parts.join('/'),
          tags: VaultParser.extractAllTags(content),
          links: VaultParser.extractWikiLinks(content),
          metadata: VaultParser.parseFrontmatter(content).metadata,
        ),
      );
    }
    return notes;
  }

  static Map<String, dynamic> buildBackupJson(List<VaultNote> notes) {
    return {
      'type': backupType,
      'version': backupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'notes': notes.map((note) => note.toMap()).toList(),
    };
  }

  static List<VaultNote> parseBackupJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Vault backup must be a JSON object.');
    }
    if (decoded['type'] != backupType) {
      throw const FormatException('Unsupported vault backup type.');
    }
    final notes = decoded['notes'];
    if (notes is! List) {
      throw const FormatException('Vault backup notes must be a list.');
    }
    return notes
        .map(
            (item) => VaultNote.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static String exportMarkdown(VaultNote note, {bool maskSecrets = true}) {
    return maskSecrets ? VaultParser.maskSecrets(note.content) : note.content;
  }

  static String exportText(VaultNote note, {bool maskSecrets = true}) {
    return VaultParser.stripFrontmatter(
        exportMarkdown(note, maskSecrets: maskSecrets));
  }

  static String exportToHtml(VaultNote note, {bool maskSecrets = true}) {
    final content = VaultParser.stripFrontmatter(
      exportMarkdown(note, maskSecrets: maskSecrets),
    );
    final lines = const HtmlEscape().convert(content).split('\n');
    final htmlLines = lines.map((line) {
      if (line.startsWith('# ')) return '<h1>${line.substring(2)}</h1>';
      if (line.startsWith('## ')) return '<h2>${line.substring(3)}</h2>';
      if (line.startsWith('### ')) return '<h3>${line.substring(4)}</h3>';
      if (line.startsWith('- ')) return '<p>&bull; ${line.substring(2)}</p>';
      if (line.trim().isEmpty) return '<br>';
      return '<p>$line</p>';
    }).join('\n');
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${const HtmlEscape().convert(note.title)}</title>
  <style>
    body { font-family: system-ui, sans-serif; line-height: 1.6; max-width: 820px; margin: 40px auto; padding: 0 20px; }
    pre, code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }
    pre { background: #f4f4f4; padding: 12px; overflow-x: auto; }
  </style>
</head>
<body>
$htmlLines
</body>
</html>
''';
  }

  static Future<UrlCheckResult> checkExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return UrlCheckResult(url: url, isReachable: false, statusCode: null);
    }
    try {
      final response = await http.head(uri).timeout(const Duration(seconds: 8));
      return UrlCheckResult(
        url: url,
        isReachable: response.statusCode >= 200 && response.statusCode < 400,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return UrlCheckResult(url: url, isReachable: false, statusCode: null);
    }
  }

  static String _archivePathFor(VaultNote note) {
    final fileName = _safePathSegment(note.fileName);
    if (note.folderPath.trim().isEmpty) return fileName;
    final folder = note.folderPath
        .split(RegExp(r'[/\\]+'))
        .map(_safePathSegment)
        .where((part) => part.isNotEmpty)
        .join('/');
    return folder.isEmpty ? fileName : '$folder/$fileName';
  }

  static bool _isSafeArchivePath(String path) {
    if (path.startsWith('/') || path.startsWith('\\')) return false;
    if (RegExp(r'^[a-zA-Z]:').hasMatch(path)) return false;
    return !path.split('/').any((part) => part == '..' || part.isEmpty);
  }

  static String _safePathSegment(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\.|\.$'), '');
  }

  static String _titleFromFileName(String fileName) {
    return fileName
        .replaceFirst(RegExp(r'\.markdown$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
  }
}

class UrlCheckResult {
  final String url;
  final bool isReachable;
  final int? statusCode;

  const UrlCheckResult({
    required this.url,
    required this.isReachable,
    required this.statusCode,
  });
}
