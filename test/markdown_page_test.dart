import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/features/markdown/presentation/markdown_page.dart';

void main() {
  testWidgets('Markdown editor preview shows formatted text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MarkdownPage())));
    // Enter markdown text
    await tester.enterText(find.byType(TextField).first, '# Title');
    await tester.pumpAndSettle();
    // Tap Preview tab
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    // Expect rendered markdown
    expect(find.text('Title'), findsOneWidget);
  });
}
