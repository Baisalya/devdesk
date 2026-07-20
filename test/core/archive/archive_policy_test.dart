import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/archive/archive_policy.dart';

Uint8List _zip(String path, List<int> content) {
  final archive = Archive()
    ..addFile(ArchiveFile(path, content.length, content));
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

Uint8List _duplicateCentralEntry(Uint8List original) {
  final originalData = ByteData.sublistView(original);
  final eocd = original.length - 22;
  final centralSize = originalData.getUint32(eocd + 12, Endian.little);
  final centralOffset = originalData.getUint32(eocd + 16, Endian.little);
  final central = original.sublist(centralOffset, eocd);
  expect(central.length, centralSize);

  final duplicated = Uint8List.fromList([
    ...original.sublist(0, eocd),
    ...central,
    ...original.sublist(eocd),
  ]);
  final newEocd = eocd + central.length;
  final data = ByteData.sublistView(duplicated);
  data.setUint16(newEocd + 8, 2, Endian.little);
  data.setUint16(newEocd + 10, 2, Endian.little);
  data.setUint32(newEocd + 12, centralSize * 2, Endian.little);
  return duplicated;
}

void main() {
  test('accepts a bounded ordinary ZIP before decompression', () {
    final bytes = _zip('folder/readme.md', 'hello'.codeUnits);
    final manifest = ArchivePolicy.inspect(bytes);
    expect(manifest.entries.single.path, 'folder/readme.md');
    expect(manifest.totalUncompressedBytes, 5);
  });

  test('rejects path traversal', () {
    final bytes = _zip('../escape.txt', 'bad'.codeUnits);
    expect(
      () => ArchivePolicy.inspect(bytes),
      throwsA(isA<ArchivePolicyException>()),
    );
  });

  test('rejects high-ratio expansion before archive decode', () {
    final bytes = _zip('bomb.txt', List<int>.filled(1024 * 1024, 0));
    expect(
      () => ArchivePolicy.inspect(bytes, maxCompressionRatio: 20),
      throwsA(isA<ArchivePolicyException>()),
    );
  });

  test('rejects local/central path mismatch', () {
    final bytes = _zip('safe.txt', 'content'.codeUnits);
    final localNameOffset = 30;
    bytes[localNameOffset] = 'x'.codeUnitAt(0);
    expect(
      () => ArchivePolicy.inspect(bytes),
      throwsA(isA<ArchivePolicyException>()),
    );
  });

  test('rejects overlapping local entry ranges', () {
    final bytes = _duplicateCentralEntry(
      _zip('same.txt', 'content'.codeUnits),
    );
    expect(
      () => ArchivePolicy.inspect(bytes),
      throwsA(
        isA<ArchivePolicyException>().having(
          (error) => error.message,
          'message',
          contains('overlapping'),
        ),
      ),
    );
  });

  test('rejects archive byte limit before parsing', () {
    expect(
      () => ArchivePolicy.inspect(
        List<int>.filled(128, 0),
        maxArchiveBytes: 64,
      ),
      throwsA(isA<ArchivePolicyException>()),
    );
  });
}
