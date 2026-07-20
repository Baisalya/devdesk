import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/files/external_file_service.dart';

ExternalFileDocument _documentFor(File file, List<int> bytes) {
  final decoded = ExternalFileDetector.decodeText(bytes);
  return ExternalFileDocument(
    name: file.uri.pathSegments.last,
    path: file.path,
    sizeBytes: bytes.length,
    content: decoded.content,
    kind: DevFileKind.text,
    canOverwriteOriginal: true,
    encoding: decoded.encoding,
    lineEnding: decoded.lineEnding,
    originalModifiedAt: file.statSync().modified.toUtc(),
    originalFingerprint: ExternalFileDetector.fingerprint(bytes),
  );
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('devdesk_atomic_file_');
    ExternalFileService.debugAtomicReplacer = null;
    ExternalFileService.debugFaultInjector = null;
  });

  tearDown(() async {
    ExternalFileService.debugAtomicReplacer = null;
    ExternalFileService.debugFaultInjector = null;
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('failed staged replacement preserves original exactly', () async {
    final file = File('${directory.path}${Platform.pathSeparator}sample.txt');
    final original = 'line1\r\nline2\r\n'.codeUnits;
    await file.writeAsBytes(original, flush: true);
    final document = _documentFor(file, original);
    ExternalFileService.debugFaultInjector = (phase) {
      if (phase == 'before_atomic_replace') throw StateError('injected');
    };

    await expectLater(
      ExternalFileService.overwriteOriginal(document, 'changed\n'),
      throwsA(isA<ExternalFileException>()),
    );
    expect(await file.readAsBytes(), original);
  });

  test('successful replacement preserves BOM and line-ending policy', () async {
    final file = File('${directory.path}${Platform.pathSeparator}sample.txt');
    final original = ExternalFileDetector.encodeText(
      'one\r\ntwo\r\n',
      encoding: ExternalTextEncoding.utf8Bom,
      lineEnding: ExternalLineEnding.crlf,
    );
    await file.writeAsBytes(original, flush: true);
    final document = _documentFor(file, original);
    ExternalFileService.debugAtomicReplacer = (temporary, target) async {
      await File(temporary).rename(target);
    };

    final updated = await ExternalFileService.overwriteOriginal(
      document,
      'alpha\nbeta\n',
    );
    final bytes = await file.readAsBytes();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(ExternalFileDetector.decodeText(bytes).content, 'alpha\r\nbeta\r\n');
    expect(
        updated.originalFingerprint, ExternalFileDetector.fingerprint(bytes));
  });

  test('changed target identity prevents overwrite', () async {
    final file = File('${directory.path}${Platform.pathSeparator}sample.txt');
    final original = 'original'.codeUnits;
    await file.writeAsBytes(original, flush: true);
    final document = _documentFor(file, original);
    await file.writeAsString('changed elsewhere', flush: true);

    await expectLater(
      ExternalFileService.overwriteOriginal(document, 'new content'),
      throwsA(isA<ExternalFileException>()),
    );
    expect(await file.readAsString(), 'changed elsewhere');
  });

  test('post-replacement verification failure restores original bytes',
      () async {
    final file = File('${directory.path}${Platform.pathSeparator}sample.txt');
    final original = 'original bytes'.codeUnits;
    await file.writeAsBytes(original, flush: true);
    final document = _documentFor(file, original);
    var replacementCalls = 0;
    ExternalFileService.debugAtomicReplacer = (temporary, target) async {
      replacementCalls++;
      if (replacementCalls == 1) {
        await File(target).writeAsString('corrupted replacement', flush: true);
        await File(temporary).delete();
        return;
      }
      await File(temporary).rename(target);
    };

    await expectLater(
      ExternalFileService.overwriteOriginal(document, 'new content'),
      throwsA(isA<ExternalFileException>()),
    );
    expect(await file.readAsBytes(), original);
    expect(replacementCalls, 2);
  });

  test('symbolic-link target is rejected where links are supported', () async {
    if (Platform.isWindows) return;
    final real = File('${directory.path}${Platform.pathSeparator}real.txt');
    await real.writeAsString('real', flush: true);
    final link = Link('${directory.path}${Platform.pathSeparator}link.txt');
    await link.create(real.path);
    final bytes = await real.readAsBytes();
    final document = ExternalFileDocument(
      name: 'link.txt',
      path: link.path,
      sizeBytes: bytes.length,
      content: 'real',
      kind: DevFileKind.text,
      canOverwriteOriginal: true,
      originalFingerprint: ExternalFileDetector.fingerprint(bytes),
    );

    await expectLater(
      ExternalFileService.overwriteOriginal(document, 'new'),
      throwsA(isA<ExternalFileException>()),
    );
    expect(await real.readAsString(), 'real');
  });
}
