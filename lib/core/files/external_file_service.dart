import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'external_file.dart';

typedef AtomicReplaceHook = Future<void> Function(
  String temporaryPath,
  String targetPath,
);

class ExternalFileService {
  static const MethodChannel _atomicChannel = MethodChannel(
    'devdesk/atomic_files',
  );

  /// Deterministic fault/replacement hook for isolated filesystem tests.
  static AtomicReplaceHook? debugAtomicReplacer;
  static FutureOr<void> Function(String phase)? debugFaultInjector;

  static Future<ExternalFileDocument?> pickDeveloperFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Open developer file',
      type: FileType.custom,
      allowedExtensions: ExternalFileDetector.supportedExtensions.toList()
        ..sort(),
      allowMultiple: false,
      withData: false,
      withReadStream: true,
      lockParentWindow: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    return readPickedFile(file);
  }

  static Future<ExternalFileDocument> readPickedFile(PlatformFile file) async {
    if (!ExternalFileDetector.isSupportedName(file.name)) {
      throw ExternalFileException(
        'Unsupported file type for "${file.name}". Open Markdown, JSON, text, code, API collection, or DevDesk backup files.',
      );
    }
    ExternalFileDetector.guardFileSize(file.size);
    final bytes = await _bytesFor(file);
    ExternalFileDetector.guardFileSize(bytes.length);
    final decoded = ExternalFileDetector.decodeText(bytes);
    final kind = ExternalFileDetector.detect(file.name, decoded.content);
    if (kind == DevFileKind.unsupported) {
      throw ExternalFileException('Unsupported file type for "${file.name}".');
    }

    DateTime? modifiedAt;
    final path = file.path;
    if (path != null && !kIsWeb) {
      try {
        modifiedAt = (await File(path).stat()).modified.toUtc();
      } catch (_) {
        modifiedAt = null;
      }
    }
    return ExternalFileDocument(
      name: file.name,
      path: path,
      identifier: file.identifier,
      sizeBytes: bytes.length,
      content: decoded.content,
      kind: kind,
      encoding: decoded.encoding,
      lineEnding: decoded.lineEnding,
      originalModifiedAt: modifiedAt,
      originalFingerprint: ExternalFileDetector.fingerprint(bytes),
      canOverwriteOriginal: _canOverwriteOriginal(file),
    );
  }

  static Future<String?> saveTextAs({
    required String suggestedName,
    required String content,
    List<String>? allowedExtensions,
    String dialogTitle = 'Save file',
  }) {
    return saveBytesAs(
      suggestedName: suggestedName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      allowedExtensions: allowedExtensions,
      dialogTitle: dialogTitle,
    );
  }

  static Future<String?> saveDocumentAs({
    required ExternalFileDocument document,
    required String content,
    String dialogTitle = 'Save file copy',
  }) {
    final bytes = ExternalFileDetector.encodeText(
      content,
      encoding: document.encoding,
      lineEnding: document.lineEnding,
    );
    return saveBytesAs(
      suggestedName: document.name,
      bytes: bytes,
      allowedExtensions:
          document.extension.isEmpty ? null : [document.extension],
      dialogTitle: dialogTitle,
    );
  }

  static Future<String?> saveBytesAs({
    required String suggestedName,
    required Uint8List bytes,
    List<String>? allowedExtensions,
    String dialogTitle = 'Save file',
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
      bytes: bytes,
      lockParentWindow: true,
    );
  }

  static Future<ExternalFileDocument> overwriteOriginal(
    ExternalFileDocument document,
    String content,
  ) async {
    final targetPath = document.path;
    if (!document.canOverwriteOriginal || targetPath == null) {
      throw const ExternalFileException(
        'Direct overwrite is unavailable for Android document URIs and this platform. Use Save As instead.',
      );
    }
    if (_isNetworkPath(targetPath)) {
      throw const ExternalFileException(
        'Direct overwrite of network paths is disabled because atomic replacement cannot be guaranteed. Use Save As.',
      );
    }

    final target = File(targetPath);
    final entityType = await FileSystemEntity.type(
      targetPath,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.notFound) {
      throw const ExternalFileException(
        'The original file no longer exists. Use Save As to avoid writing to the wrong target.',
      );
    }
    if (entityType == FileSystemEntityType.link) {
      throw const ExternalFileException(
        'Direct overwrite of symbolic links or reparse targets is disabled. Use Save As.',
      );
    }
    if (entityType != FileSystemEntityType.file) {
      throw const ExternalFileException('The original target is not a file.');
    }

    await _verifyOriginalIdentity(document, target);
    final bytes = ExternalFileDetector.encodeText(
      content,
      encoding: document.encoding,
      lineEnding: document.lineEnding,
    );
    ExternalFileDetector.guardFileSize(bytes.length);

    final parent = target.parent;
    final unique = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    final temporary = File(
      p.join(parent.path, '.${p.basename(targetPath)}.devdesk-$unique.tmp'),
    );
    final rollback = File(
      p.join(
        parent.path,
        '.${p.basename(targetPath)}.devdesk-recovery-$unique.tmp',
      ),
    );
    var replacementAttempted = false;
    var rollbackMayBeDeleted = true;
    late Uint8List originalBytes;
    try {
      await _injectFault('before_temp_write');
      await _writeExclusiveAndFlush(temporary, bytes);
      await _injectFault('after_temp_flush');
      final stagedBytes = await temporary.readAsBytes();
      if (ExternalFileDetector.fingerprint(stagedBytes) !=
          ExternalFileDetector.fingerprint(bytes)) {
        throw const ExternalFileException(
          'The staged file could not be verified. The original was not changed.',
        );
      }

      originalBytes = await _verifyOriginalIdentity(document, target);
      await _writeExclusiveAndFlush(rollback, originalBytes);
      final rollbackBytes = await rollback.readAsBytes();
      if (ExternalFileDetector.fingerprint(rollbackBytes) !=
          ExternalFileDetector.fingerprint(originalBytes)) {
        throw const ExternalFileException(
          'A recovery copy could not be verified. The original was not changed.',
        );
      }

      await _injectFault('before_atomic_replace');
      replacementAttempted = true;
      await _atomicReplace(temporary.path, targetPath);
      final updatedBytes = await target.readAsBytes();
      if (ExternalFileDetector.fingerprint(updatedBytes) !=
          ExternalFileDetector.fingerprint(bytes)) {
        throw const ExternalFileException(
          'The replacement could not be verified.',
        );
      }
      final updatedStat = await target.stat();
      return document.copyWith(
        sizeBytes: updatedBytes.length,
        content: content,
        originalModifiedAt: updatedStat.modified.toUtc(),
        originalFingerprint: ExternalFileDetector.fingerprint(updatedBytes),
      );
    } catch (error) {
      if (replacementAttempted) {
        final recovered = await _restoreOriginalIfNeeded(
          target: target,
          rollback: rollback,
          originalBytes: originalBytes,
        );
        rollbackMayBeDeleted = recovered;
        if (!recovered) {
          throw const ExternalFileException(
            'The save failed and automatic rollback could not be verified. A .devdesk-recovery file was left beside the original; keep it until the file is recovered.',
          );
        }
      }
      if (error is ExternalFileException) rethrow;
      if (error is FileSystemException) {
        throw ExternalFileException(_fileSystemMessage(error));
      }
      if (error is PlatformException) {
        throw const ExternalFileException(
          'The operating system could not replace the file atomically. The original was preserved; use Save As.',
        );
      }
      throw const ExternalFileException(
        'The file could not be replaced safely. The original was preserved; use Save As.',
      );
    } finally {
      await _deleteBestEffort(temporary);
      if (rollbackMayBeDeleted) await _deleteBestEffort(rollback);
    }
  }

  static Future<Uint8List> _verifyOriginalIdentity(
    ExternalFileDocument document,
    File target,
  ) async {
    final entityType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.link) {
      throw const ExternalFileException(
        'The original target became a symbolic link or reparse target. The original was preserved.',
      );
    }
    if (entityType != FileSystemEntityType.file) {
      throw const ExternalFileException('The original target changed type.');
    }
    final stat = await target.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const ExternalFileException('The original target changed type.');
    }
    if (stat.size > ExternalFileDetector.maxFileBytes) {
      throw const ExternalFileException(
        'The original file changed and is now above the safe size limit.',
      );
    }
    final current = await target.readAsBytes();
    final currentFingerprint = ExternalFileDetector.fingerprint(current);
    if (document.originalFingerprint != null &&
        currentFingerprint != document.originalFingerprint) {
      throw const ExternalFileException(
        'The original file changed after it was opened. Reload it or use Save As.',
      );
    }
    return Uint8List.fromList(current);
  }

  static Future<void> _writeExclusiveAndFlush(
    File file,
    List<int> bytes,
  ) async {
    // Dart does not expose an exclusive FileMode. Claim the temporary path
    // atomically first, then open the file we just created for writing.
    await file.create(exclusive: true);
    final handle = await file.open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  static Future<bool> _restoreOriginalIfNeeded({
    required File target,
    required File rollback,
    required List<int> originalBytes,
  }) async {
    final expected = ExternalFileDetector.fingerprint(originalBytes);
    try {
      if (await target.exists()) {
        final current = await target.readAsBytes();
        if (ExternalFileDetector.fingerprint(current) == expected) return true;
      }
      if (!await rollback.exists()) return false;
      await _atomicReplace(rollback.path, target.path);
      if (!await target.exists()) return false;
      final restored = await target.readAsBytes();
      return ExternalFileDetector.fingerprint(restored) == expected;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A recovery/temp file is safer than touching the user's original.
    }
  }

  static Future<void> _atomicReplace(
    String temporaryPath,
    String targetPath,
  ) async {
    final hook = debugAtomicReplacer;
    if (hook != null) {
      await hook(temporaryPath, targetPath);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await _atomicChannel.invokeMethod<void>('replace', {
        'temporaryPath': temporaryPath,
        'targetPath': targetPath,
      });
      return;
    }
    // POSIX rename within one directory is atomic and replaces the destination.
    await File(temporaryPath).rename(targetPath);
  }

  static Future<Uint8List> _bytesFor(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.readStream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readStream!) {
        builder.add(chunk);
        ExternalFileDetector.guardFileSize(builder.length);
      }
      return builder.takeBytes();
    }
    final path = file.path;
    if (path == null) {
      throw const ExternalFileException(
        'The selected Android document URI could not be read. Reopen it with document access or use a local copy.',
      );
    }
    return File(path).readAsBytes();
  }

  static bool _canOverwriteOriginal(PlatformFile file) {
    if (file.path == null || file.identifier != null || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool _isNetworkPath(String path) {
    return path.startsWith(r'\\') || path.startsWith('//');
  }

  static String _fileSystemMessage(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 5 || code == 13) {
      return 'The file is read-only or access was denied. The original was preserved; use Save As.';
    }
    if (code == 32 || code == 33) {
      return 'The file is locked by another application. Close it there and retry.';
    }
    return 'The file could not be replaced safely. The original was preserved; use Save As.';
  }

  static Future<void> _injectFault(String phase) async {
    final hook = debugFaultInjector;
    if (hook != null) await hook(phase);
  }
}

extension _SingleOrNull<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
