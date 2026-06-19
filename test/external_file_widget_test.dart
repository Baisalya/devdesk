import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('Dashboard shows Open File quick action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardPage())),
    );

    expect(find.text('Open File'), findsOneWidget);
  });
}
