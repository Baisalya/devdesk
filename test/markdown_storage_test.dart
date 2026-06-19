import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/markdown/provider/markdown_provider.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_markdown_test');
    LocalStorage.initializeForTest(dir.path);
  });

  test('markdown file storage save, reopen, rename and delete', () async {
    final box =
        await LocalStorage.openBox<String>(LocalStorage.markdownFilesBox);
    await box.clear();

    await saveMarkdownFile('notes', '# Notes');
    expect(await loadMarkdownFile('notes.md'), '# Notes');

    await renameMarkdownFile('notes.md', 'renamed');
    expect(await loadMarkdownFile('notes.md'), isNull);
    expect(await loadMarkdownFile('renamed.md'), '# Notes');

    await deleteMarkdownFile('renamed.md');
    expect(await loadMarkdownFile('renamed.md'), isNull);
  });

  test('markdown filename validation rejects invalid names', () {
    expect(() => normalizeMarkdownFileName(''), throwsArgumentError);
    expect(() => normalizeMarkdownFileName('bad/name'), throwsArgumentError);
  });
}
