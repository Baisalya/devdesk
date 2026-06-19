import 'dart:convert';

import '../storage/local_storage.dart';

enum DevFileKind {
  markdown,
  json,
  text,
  apiCollection,
  backup,
  unsupported,
}

class ExternalFileException implements Exception {
  final String message;

  const ExternalFileException(this.message);

  @override
  String toString() => message;
}

class ExternalFileDocument {
  final String name;
  final String? path;
  final String? identifier;
  final int sizeBytes;
  final String content;
  final DevFileKind kind;
  final bool canOverwriteOriginal;

  const ExternalFileDocument({
    required this.name,
    required this.sizeBytes,
    required this.content,
    required this.kind,
    this.path,
    this.identifier,
    this.canOverwriteOriginal = false,
  });

  String get extension => ExternalFileDetector.extensionOf(name);

  bool get isEnvLike {
    final lower = name.toLowerCase();
    return lower == '.env' || lower.endsWith('.env') || lower.contains('.env.');
  }

  String get sourceLabel => path == null ? name : path!;
}

class ExternalFileDetector {
  static const maxFileBytes = 5 * 1024 * 1024;

  static const supportedExtensions = <String>{
    'md',
    'markdown',
    'txt',
    'log',
    'json',
    'yaml',
    'yml',
    'xml',
    'html',
    'css',
    'js',
    'ts',
    'dart',
    'py',
    'java',
    'kt',
    'swift',
    'sh',
    'bat',
    'env',
  };

  static const textExtensions = <String>{
    'txt',
    'log',
    'yaml',
    'yml',
    'xml',
    'html',
    'css',
    'js',
    'ts',
    'dart',
    'py',
    'java',
    'kt',
    'swift',
    'sh',
    'bat',
    'env',
  };

  static DevFileKind detect(String fileName, String content) {
    final lower = fileName.toLowerCase();
    final ext = extensionOf(fileName);
    if (_isReadme(lower) || ext == 'md' || ext == 'markdown') {
      return DevFileKind.markdown;
    }
    if (ext == 'json') {
      if (looksLikeDevDeskBackup(content)) {
        return DevFileKind.backup;
      }
      if (looksLikeApiCollection(content)) {
        return DevFileKind.apiCollection;
      }
      return DevFileKind.json;
    }
    if (textExtensions.contains(ext)) {
      return DevFileKind.text;
    }
    return DevFileKind.unsupported;
  }

  static String extensionOf(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    if (normalized == '.env') return 'env';
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) return '';
    return normalized.substring(dot + 1);
  }

  static bool isSupportedName(String fileName) {
    final lower = fileName.toLowerCase();
    return _isReadme(lower) || supportedExtensions.contains(extensionOf(lower));
  }

  static String decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const ExternalFileException(
        'This file is not valid UTF-8 text. Binary or non-UTF-8 files are not supported.',
      );
    }
  }

  static void guardFileSize(int sizeBytes) {
    if (sizeBytes > maxFileBytes) {
      throw ExternalFileException(
        'File is too large (${_formatBytes(sizeBytes)}). The safe limit is ${_formatBytes(maxFileBytes)}.',
      );
    }
  }

  static bool looksLikeDevDeskBackup(String content) {
    final decoded = _tryDecodeObject(content);
    if (decoded == null) return false;
    if (decoded['type'] == 'devdesk_backup') return true;
    final boxes = decoded['boxes'];
    if (boxes is Map &&
        LocalStorage.knownBoxes.any((boxName) => boxes.containsKey(boxName))) {
      return true;
    }
    return LocalStorage.knownBoxes.any(decoded.containsKey);
  }

  static bool looksLikeApiCollection(String content) {
    final decoded = _tryDecodeObject(content);
    if (decoded == null) return false;
    if (decoded['type'] == 'devdesk_api_collection' ||
        decoded['type'] == 'devdesk_api_collection_v2' ||
        decoded['type'] == 'devdesk_api_workspace') {
      return true;
    }
    final requests = decoded['requests'];
    return requests is List &&
        requests.any(
          (item) =>
              item is Map && item['method'] is String && item['url'] is String,
        );
  }

  static Map<String, dynamic>? _tryDecodeObject(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static bool _isReadme(String lowerFileName) {
    return lowerFileName == 'readme.md' ||
        lowerFileName == 'readme.markdown' ||
        lowerFileName == 'readme.txt' ||
        lowerFileName.endsWith('/readme.md') ||
        lowerFileName.endsWith(r'\readme.md') ||
        lowerFileName.endsWith('/readme.txt') ||
        lowerFileName.endsWith(r'\readme.txt');
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
