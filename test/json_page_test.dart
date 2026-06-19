import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/features/json_tools/presentation/json_page.dart';

void main() {
  testWidgets('JSON formatter shows error on invalid input',
      (WidgetTester tester) async {
    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: JsonPage())));
    // Enter invalid JSON
    await tester.enterText(find.byType(TextField).first, '{invalid');
    await tester.pumpAndSettle();
    // Tap Format button
    await tester.tap(find.text('Format'));
    await tester.pumpAndSettle();
    // Expect error message containing 'Invalid'
    expect(find.textContaining('Invalid'), findsWidgets);
  });
}
