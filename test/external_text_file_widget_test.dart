import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/external_files/presentation/text_file_page.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_text_file_test');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  testWidgets('Text file page can save external text as snippet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TextFilePage(
            document: ExternalFileDocument(
              name: 'script.dart',
              sizeBytes: 'void main() {}'.length,
              content: 'void main() {}',
              kind: DevFileKind.text,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save as Snippet'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    expect(box.values.single['title'], 'script.dart');
    expect(box.values.single['content'], 'void main() {}');
  });
}
