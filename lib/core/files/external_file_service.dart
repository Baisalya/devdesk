import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'external_file.dart';

class ExternalFileService {
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
    final content = ExternalFileDetector.decodeUtf8(bytes);
    final kind = ExternalFileDetector.detect(file.name, content);
    if (kind == DevFileKind.unsupported) {
      throw ExternalFileException('Unsupported file type for "${file.name}".');
    }
    return ExternalFileDocument(
      name: file.name,
      path: file.path,
      identifier: file.identifier,
      sizeBytes: bytes.length,
      content: content,
      kind: kind,
      canOverwriteOriginal: _canOverwriteOriginal(file),
    );
  }

  static Future<String?> saveTextAs({
    required String suggestedName,
    required String content,
    List<String>? allowedExtensions,
    String dialogTitle = 'Save file',
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
      bytes: Uint8List.fromList(utf8.encode(content)),
      lockParentWindow: true,
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

  static Future<void> overwriteOriginal(
    ExternalFileDocument document,
    String content,
  ) async {
    if (!document.canOverwriteOriginal || document.path == null) {
      throw const ExternalFileException(
        'Direct overwrite is not available for this file on this platform. Use Save As instead.',
      );
    }
    await File(document.path!).writeAsString(content);
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
        'The selected file could not be read by this platform.',
      );
    }
    return File(path).readAsBytes();
  }

  static bool _canOverwriteOriginal(PlatformFile file) {
    if (file.path == null || file.identifier != null || kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }
}

extension _SingleOrNull<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
