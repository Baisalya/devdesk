import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/features/json_tools/presentation/json_page.dart';
import 'package:devdesk/features/markdown/presentation/markdown_page.dart';

void main() {
  testWidgets('External markdown opens in Markdown editor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MarkdownPage(
            initialDocument: _document(
              name: 'README.md',
              kind: DevFileKind.markdown,
              content: '# External README',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('README.md'), findsOneWidget);
    expect(find.textContaining('External'), findsWidgets);
    expect(find.textContaining('# External README'), findsOneWidget);
  });

  testWidgets('External invalid JSON remains editable and shows error',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: JsonPage(
            initialDocument: _document(
              name: 'bad.json',
              kind: DevFileKind.json,
              content: '{invalid',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Invalid JSON'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });
}

ExternalFileDocument _document({
  required String name,
  required DevFileKind kind,
  required String content,
}) {
  return ExternalFileDocument(
    name: name,
    sizeBytes: content.length,
    content: content,
    kind: kind,
  );
}
