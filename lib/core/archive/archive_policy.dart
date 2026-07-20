import 'dart:convert';
import 'dart:typed_data';

class ArchivePolicyException extends FormatException {
  const ArchivePolicyException(super.message);
}

class SafeZipEntry {
  final String path;
  final int compressedSize;
  final int uncompressedSize;
  final int compressionMethod;
  final bool isDirectory;

  const SafeZipEntry({
    required this.path,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.compressionMethod,
    required this.isDirectory,
  });
}

class SafeZipManifest {
  final List<SafeZipEntry> entries;
  final int totalCompressedBytes;
  final int totalUncompressedBytes;

  const SafeZipManifest({
    required this.entries,
    required this.totalCompressedBytes,
    required this.totalUncompressedBytes,
  });
}

/// Reads only the ZIP end record and central directory, so entry count, names,
/// declared expansion, compression methods, encryption, and ratios are checked
/// before an archive library is allowed to inflate file contents.
class ArchivePolicy {
  ArchivePolicy._();

  static const int defaultMaxArchiveBytes = 10 * 1024 * 1024;
  static const int defaultMaxEntries = 1000;
  static const int defaultMaxEntryBytes = 5 * 1024 * 1024;
  static const int defaultMaxExpandedBytes = 25 * 1024 * 1024;
  static const int defaultMaxCompressionRatio = 100;
  static const int defaultMaxPathDepth = 20;
  static const int defaultMaxPathBytes = 512;

  static SafeZipManifest inspect(
    List<int> input, {
    int maxArchiveBytes = defaultMaxArchiveBytes,
    int maxEntries = defaultMaxEntries,
    int maxEntryBytes = defaultMaxEntryBytes,
    int maxExpandedBytes = defaultMaxExpandedBytes,
    int maxCompressionRatio = defaultMaxCompressionRatio,
    int maxPathDepth = defaultMaxPathDepth,
    int maxPathBytes = defaultMaxPathBytes,
  }) {
    if (input.length > maxArchiveBytes) {
      throw const ArchivePolicyException(
          'ZIP file is larger than the safe limit.');
    }
    if (input.length < 22) {
      throw const ArchivePolicyException('ZIP file is truncated.');
    }
    final bytes = Uint8List.fromList(input);
    final data = ByteData.sublistView(bytes);
    final eocd = _findEndOfCentralDirectory(data);
    final diskNumber = data.getUint16(eocd + 4, Endian.little);
    final centralDisk = data.getUint16(eocd + 6, Endian.little);
    final entriesOnDisk = data.getUint16(eocd + 8, Endian.little);
    final entryCount = data.getUint16(eocd + 10, Endian.little);
    if (diskNumber != 0 || centralDisk != 0 || entriesOnDisk != entryCount) {
      throw const ArchivePolicyException(
        'Multi-disk ZIP archives are not supported by the safe importer.',
      );
    }
    final centralSize = data.getUint32(eocd + 12, Endian.little);
    final centralOffset = data.getUint32(eocd + 16, Endian.little);
    if (entryCount == 0xFFFF ||
        centralSize == 0xFFFFFFFF ||
        centralOffset == 0xFFFFFFFF) {
      throw const ArchivePolicyException(
        'ZIP64 archives are not supported by the safe importer.',
      );
    }
    if (entryCount > maxEntries) {
      throw const ArchivePolicyException('ZIP contains too many entries.');
    }
    if (centralOffset + centralSize > eocd ||
        centralOffset < 0 ||
        centralSize < 0) {
      throw const ArchivePolicyException('ZIP central directory is invalid.');
    }

    final entries = <SafeZipEntry>[];
    final occupiedRanges = <({int start, int end})>[];
    final normalizedNames = <String>{};
    var cursor = centralOffset;
    var totalCompressed = 0;
    var totalExpanded = 0;
    for (var index = 0; index < entryCount; index++) {
      if (cursor + 46 > centralOffset + centralSize ||
          data.getUint32(cursor, Endian.little) != 0x02014B50) {
        throw const ArchivePolicyException(
            'ZIP central directory is malformed.');
      }
      final flags = data.getUint16(cursor + 8, Endian.little);
      final method = data.getUint16(cursor + 10, Endian.little);
      final compressed = data.getUint32(cursor + 20, Endian.little);
      final expanded = data.getUint32(cursor + 24, Endian.little);
      final nameLength = data.getUint16(cursor + 28, Endian.little);
      final extraLength = data.getUint16(cursor + 30, Endian.little);
      final commentLength = data.getUint16(cursor + 32, Endian.little);
      final externalAttributes = data.getUint32(cursor + 38, Endian.little);
      final localHeaderOffset = data.getUint32(cursor + 42, Endian.little);
      final end = cursor + 46 + nameLength + extraLength + commentLength;
      if (end > centralOffset + centralSize || nameLength == 0) {
        throw const ArchivePolicyException('ZIP entry metadata is truncated.');
      }
      if ((flags & 0x1) != 0) {
        throw const ArchivePolicyException(
            'Encrypted ZIP entries are not supported.');
      }
      if (method != 0 && method != 8) {
        throw ArchivePolicyException(
          'ZIP compression method $method is not supported safely.',
        );
      }
      if (nameLength > maxPathBytes) {
        throw const ArchivePolicyException('ZIP contains an oversized path.');
      }
      if (localHeaderOffset + 30 > centralOffset) {
        throw const ArchivePolicyException(
            'ZIP entry points outside file data.');
      }

      final nameBytes = bytes.sublist(cursor + 46, cursor + 46 + nameLength);
      final path = _decodeName(nameBytes, utf8Flag: (flags & 0x800) != 0)
          .replaceAll('\\', '/');
      _validatePath(path, maxDepth: maxPathDepth);
      final occupied = _validateLocalHeader(
        bytes,
        data,
        path: path,
        centralFlags: flags,
        centralMethod: method,
        centralCompressed: compressed,
        centralExpanded: expanded,
        localHeaderOffset: localHeaderOffset,
        centralOffset: centralOffset,
        maxPathBytes: maxPathBytes,
      );
      if (occupiedRanges.any(
        (range) => occupied.start < range.end && occupied.end > range.start,
      )) {
        throw const ArchivePolicyException(
          'ZIP entries contain overlapping local data.',
        );
      }
      occupiedRanges.add(occupied);
      final unixType = (externalAttributes >> 16) & 0xF000;
      if (unixType == 0xA000) {
        throw const ArchivePolicyException(
          'ZIP symbolic-link entries are not supported.',
        );
      }
      final unique = path.toLowerCase();
      if (!normalizedNames.add(unique)) {
        throw const ArchivePolicyException('ZIP contains duplicate paths.');
      }
      final isDirectory = path.endsWith('/');
      if (!isDirectory && expanded > maxEntryBytes) {
        throw ArchivePolicyException('ZIP entry is too large: $path');
      }
      if (compressed == 0 && expanded > 0) {
        throw ArchivePolicyException(
            'ZIP entry has an unsafe compression ratio: $path');
      }
      if (compressed > 0 && expanded > compressed * maxCompressionRatio) {
        throw ArchivePolicyException(
            'ZIP entry has an unsafe compression ratio: $path');
      }
      totalCompressed += compressed;
      totalExpanded += expanded;
      if (totalExpanded > maxExpandedBytes) {
        throw const ArchivePolicyException(
            'ZIP expands beyond the safe limit.');
      }
      entries.add(
        SafeZipEntry(
          path: path,
          compressedSize: compressed,
          uncompressedSize: expanded,
          compressionMethod: method,
          isDirectory: isDirectory,
        ),
      );
      cursor = end;
    }
    if (cursor != centralOffset + centralSize) {
      throw const ArchivePolicyException(
          'ZIP central directory length is inconsistent.');
    }
    return SafeZipManifest(
      entries: entries,
      totalCompressedBytes: totalCompressed,
      totalUncompressedBytes: totalExpanded,
    );
  }

  static int _findEndOfCentralDirectory(ByteData data) {
    final minimum = data.lengthInBytes - 22 - 0xFFFF;
    final start = minimum < 0 ? 0 : minimum;
    for (var index = data.lengthInBytes - 22; index >= start; index--) {
      if (data.getUint32(index, Endian.little) == 0x06054B50) {
        final commentLength = data.getUint16(index + 20, Endian.little);
        if (index + 22 + commentLength == data.lengthInBytes) return index;
      }
    }
    throw const ArchivePolicyException('ZIP end record was not found.');
  }

  static String _decodeName(List<int> bytes, {required bool utf8Flag}) {
    try {
      return utf8Flag ? utf8.decode(bytes) : latin1.decode(bytes);
    } on FormatException {
      throw const ArchivePolicyException('ZIP contains an invalid file name.');
    }
  }

  static ({int start, int end}) _validateLocalHeader(
    Uint8List bytes,
    ByteData data, {
    required String path,
    required int centralFlags,
    required int centralMethod,
    required int centralCompressed,
    required int centralExpanded,
    required int localHeaderOffset,
    required int centralOffset,
    required int maxPathBytes,
  }) {
    if (data.getUint32(localHeaderOffset, Endian.little) != 0x04034B50) {
      throw const ArchivePolicyException('ZIP local header is malformed.');
    }
    final flags = data.getUint16(localHeaderOffset + 6, Endian.little);
    final method = data.getUint16(localHeaderOffset + 8, Endian.little);
    final compressed = data.getUint32(localHeaderOffset + 18, Endian.little);
    final expanded = data.getUint32(localHeaderOffset + 22, Endian.little);
    final nameLength = data.getUint16(localHeaderOffset + 26, Endian.little);
    final extraLength = data.getUint16(localHeaderOffset + 28, Endian.little);
    if (nameLength == 0 || nameLength > maxPathBytes) {
      throw const ArchivePolicyException('ZIP local path is invalid.');
    }
    final dataStart = localHeaderOffset + 30 + nameLength + extraLength;
    if (dataStart > centralOffset ||
        dataStart + centralCompressed > centralOffset) {
      throw const ArchivePolicyException('ZIP entry data overlaps metadata.');
    }
    if ((flags & 0x1) != 0 || (centralFlags & 0x1) != 0) {
      throw const ArchivePolicyException(
          'Encrypted ZIP entries are not supported.');
    }
    if (method != centralMethod ||
        ((flags ^ centralFlags) & (0x1 | 0x8 | 0x800)) != 0) {
      throw const ArchivePolicyException(
        'ZIP local and central metadata are inconsistent.',
      );
    }
    if ((flags & 0x8) == 0 &&
        (compressed != centralCompressed || expanded != centralExpanded)) {
      throw const ArchivePolicyException(
        'ZIP entry sizes are inconsistent.',
      );
    }
    final localNameBytes = bytes.sublist(
      localHeaderOffset + 30,
      localHeaderOffset + 30 + nameLength,
    );
    final localPath = _decodeName(
      localNameBytes,
      utf8Flag: (flags & 0x800) != 0,
    ).replaceAll('\\', '/');
    if (localPath != path) {
      throw const ArchivePolicyException(
        'ZIP local and central paths do not match.',
      );
    }
    return (
      start: localHeaderOffset,
      end: dataStart + centralCompressed,
    );
  }

  static void _validatePath(String path, {required int maxDepth}) {
    if (path.contains('\u0000') ||
        path.startsWith('/') ||
        path.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      throw const ArchivePolicyException(
          'ZIP contains an unsafe absolute path.');
    }
    final parts = path.split('/');
    final meaningful = parts.where((part) => part.isNotEmpty).toList();
    if (meaningful.isEmpty || meaningful.length > maxDepth) {
      throw const ArchivePolicyException('ZIP path depth is unsafe.');
    }
    if (meaningful.any(
      (part) => part == '.' || part == '..' || part.trim().isEmpty,
    )) {
      throw const ArchivePolicyException('ZIP contains path traversal.');
    }
  }
}
