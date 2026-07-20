import 'dart:convert';
import 'dart:typed_data';

import '../storage/local_storage.dart';

enum DevFileKind {
  markdown,
  json,
  text,
  apiCollection,
  backup,
  unsupported,
}

enum ExternalTextEncoding { utf8, utf8Bom, utf16LittleEndian, utf16BigEndian }

enum ExternalLineEnding { none, lf, crlf, cr, mixed }

class ExternalFileException implements Exception {
  final String message;

  const ExternalFileException(this.message);

  @override
  String toString() => message;
}

class DecodedExternalText {
  final String content;
  final ExternalTextEncoding encoding;
  final ExternalLineEnding lineEnding;

  const DecodedExternalText({
    required this.content,
    required this.encoding,
    required this.lineEnding,
  });
}

class ExternalFileDocument {
  final String name;
  final String? path;
  final String? identifier;
  final int sizeBytes;
  final String content;
  final DevFileKind kind;
  final bool canOverwriteOriginal;
  final ExternalTextEncoding encoding;
  final ExternalLineEnding lineEnding;
  final DateTime? originalModifiedAt;
  final String? originalFingerprint;

  const ExternalFileDocument({
    required this.name,
    required this.sizeBytes,
    required this.content,
    required this.kind,
    this.path,
    this.identifier,
    this.canOverwriteOriginal = false,
    this.encoding = ExternalTextEncoding.utf8,
    this.lineEnding = ExternalLineEnding.none,
    this.originalModifiedAt,
    this.originalFingerprint,
  });

  ExternalFileDocument copyWith({
    String? name,
    String? path,
    String? identifier,
    int? sizeBytes,
    String? content,
    DevFileKind? kind,
    bool? canOverwriteOriginal,
    ExternalTextEncoding? encoding,
    ExternalLineEnding? lineEnding,
    DateTime? originalModifiedAt,
    String? originalFingerprint,
  }) {
    return ExternalFileDocument(
      name: name ?? this.name,
      path: path ?? this.path,
      identifier: identifier ?? this.identifier,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      content: content ?? this.content,
      kind: kind ?? this.kind,
      canOverwriteOriginal: canOverwriteOriginal ?? this.canOverwriteOriginal,
      encoding: encoding ?? this.encoding,
      lineEnding: lineEnding ?? this.lineEnding,
      originalModifiedAt: originalModifiedAt ?? this.originalModifiedAt,
      originalFingerprint: originalFingerprint ?? this.originalFingerprint,
    );
  }

  String get extension => ExternalFileDetector.extensionOf(name);

  bool get isEnvLike {
    final lower = name.toLowerCase();
    return lower == '.env' || lower.endsWith('.env') || lower.contains('.env.');
  }

  bool get isAndroidContentUri => identifier?.startsWith('content://') == true;

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
      if (looksLikeDevDeskBackup(content)) return DevFileKind.backup;
      if (looksLikeApiCollection(content)) return DevFileKind.apiCollection;
      return DevFileKind.json;
    }
    if (textExtensions.contains(ext)) return DevFileKind.text;
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

  static DecodedExternalText decodeText(List<int> rawBytes) {
    final bytes = Uint8List.fromList(rawBytes);
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      final content = _decodeUtf8(bytes.sublist(3));
      return DecodedExternalText(
        content: content,
        encoding: ExternalTextEncoding.utf8Bom,
        lineEnding: detectLineEnding(content),
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final content = _decodeUtf16(bytes.sublist(2), littleEndian: true);
      return DecodedExternalText(
        content: content,
        encoding: ExternalTextEncoding.utf16LittleEndian,
        lineEnding: detectLineEnding(content),
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final content = _decodeUtf16(bytes.sublist(2), littleEndian: false);
      return DecodedExternalText(
        content: content,
        encoding: ExternalTextEncoding.utf16BigEndian,
        lineEnding: detectLineEnding(content),
      );
    }
    final content = _decodeUtf8(bytes);
    return DecodedExternalText(
      content: content,
      encoding: ExternalTextEncoding.utf8,
      lineEnding: detectLineEnding(content),
    );
  }

  static String decodeUtf8(List<int> bytes) => _decodeUtf8(bytes);

  static Uint8List encodeText(
    String content, {
    required ExternalTextEncoding encoding,
    required ExternalLineEnding lineEnding,
  }) {
    final normalized = normalizeLineEndings(content, lineEnding);
    switch (encoding) {
      case ExternalTextEncoding.utf8:
        return Uint8List.fromList(utf8.encode(normalized));
      case ExternalTextEncoding.utf8Bom:
        return Uint8List.fromList(
            [0xEF, 0xBB, 0xBF, ...utf8.encode(normalized)]);
      case ExternalTextEncoding.utf16LittleEndian:
        return Uint8List.fromList([
          0xFF,
          0xFE,
          ..._encodeUtf16(normalized, littleEndian: true),
        ]);
      case ExternalTextEncoding.utf16BigEndian:
        return Uint8List.fromList([
          0xFE,
          0xFF,
          ..._encodeUtf16(normalized, littleEndian: false),
        ]);
    }
  }

  static ExternalLineEnding detectLineEnding(String content) {
    final crlf = RegExp(r'\r\n').allMatches(content).length;
    final withoutCrlf = content.replaceAll('\r\n', '');
    final lf = '\n'.allMatches(withoutCrlf).length;
    final cr = '\r'.allMatches(withoutCrlf).length;
    final kinds = [crlf, lf, cr].where((count) => count > 0).length;
    if (kinds == 0) return ExternalLineEnding.none;
    if (kinds > 1) return ExternalLineEnding.mixed;
    if (crlf > 0) return ExternalLineEnding.crlf;
    if (lf > 0) return ExternalLineEnding.lf;
    return ExternalLineEnding.cr;
  }

  static String normalizeLineEndings(
    String content,
    ExternalLineEnding lineEnding,
  ) {
    if (lineEnding == ExternalLineEnding.none ||
        lineEnding == ExternalLineEnding.mixed) {
      return content;
    }
    final lf = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return switch (lineEnding) {
      ExternalLineEnding.crlf => lf.replaceAll('\n', '\r\n'),
      ExternalLineEnding.cr => lf.replaceAll('\n', '\r'),
      _ => lf,
    };
  }

  static String fingerprint(List<int> bytes) {
    // Two FNV-1a 32-bit lanes are sufficient for non-cryptographic change
    // detection and avoid a costly BigInt allocation for every input byte.
    var first = 0x811C9DC5;
    var second = 0x9E3779B9;
    for (var index = 0; index < bytes.length; index++) {
      final byte = bytes[index];
      first = ((first ^ byte) * 0x01000193) & 0xFFFFFFFF;
      second = ((second ^ (byte + index)) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${first.toRadixString(16).padLeft(8, '0')}'
        '${second.toRadixString(16).padLeft(8, '0')}';
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
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const ExternalFileException(
        'This file is not valid UTF-8/UTF-16 text. Binary files are not supported.',
      );
    }
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    if (bytes.length.isOdd) {
      throw const ExternalFileException('The UTF-16 file is truncated.');
    }
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      final first = bytes[index];
      final second = bytes[index + 1];
      units.add(littleEndian ? first | (second << 8) : (first << 8) | second);
    }
    try {
      return String.fromCharCodes(units);
    } catch (_) {
      throw const ExternalFileException('The UTF-16 file is invalid.');
    }
  }

  static List<int> _encodeUtf16(
    String content, {
    required bool littleEndian,
  }) {
    final output = <int>[];
    for (final unit in content.codeUnits) {
      final low = unit & 0xFF;
      final high = (unit >> 8) & 0xFF;
      output.addAll(littleEndian ? [low, high] : [high, low]);
    }
    return output;
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
