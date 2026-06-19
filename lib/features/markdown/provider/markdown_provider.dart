import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

/// Provider for managing the current markdown text being edited. Holds a
/// simple `String` state.
final markdownTextProvider = StateProvider<String>((ref) => '');

/// Provider for accessing the list of saved markdown files. Files are stored
/// in a Hive box named `markdown_files` where the key is the filename and
/// the value is the content.
final markdownFilesProvider = FutureProvider<List<String>>((ref) async {
  final box = await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
  final files = box.keys.cast<String>().toList()..sort();
  return files;
});

/// Saves a markdown file to the Hive box. If a file with the same name
/// exists it will be overwritten.
Future<void> saveMarkdownFile(String fileName, String content) async {
  final normalized = normalizeMarkdownFileName(fileName);
  final box = await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
  await box.put(normalized, content);
}

/// Loads the content of a markdown file. Returns null if not found.
Future<String?> loadMarkdownFile(String fileName) async {
  final box = await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
  return box.get(fileName);
}

Future<void> deleteMarkdownFile(String fileName) async {
  final box = await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
  await box.delete(fileName);
}

Future<void> renameMarkdownFile(String oldName, String newName) async {
  final normalized = normalizeMarkdownFileName(newName);
  final box = await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
  final content = box.get(oldName);
  if (content == null) {
    throw ArgumentError('File "$oldName" was not found.');
  }
  await box.put(normalized, content);
  if (normalized != oldName) {
    await box.delete(oldName);
  }
}

String normalizeMarkdownFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('File name is required.');
  }
  if (trimmed.contains(RegExp(r'[\\/:*?"<>|]'))) {
    throw ArgumentError('File name contains invalid characters.');
  }
  return trimmed.endsWith('.md') ? trimmed : '$trimmed.md';
}
