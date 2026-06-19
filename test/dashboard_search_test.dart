import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('Search filters dashboard tools', (WidgetTester tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DashboardPage())));
    // Initially, Markdown Editor should be visible
    expect(find.text('Markdown Editor'), findsOneWidget);
    // Enter search for 'UUID'
    await tester.enterText(find.byType(TextField).first, 'UUID');
    await tester.pumpAndSettle();
    // Now Markdown Editor should not be found
    expect(find.text('Markdown Editor'), findsNothing);
    // And UUID Generator should be visible
    expect(find.text('UUID Generator'), findsOneWidget);
  });
}
