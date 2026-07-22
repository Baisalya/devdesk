import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/app/theme/theme_controller.dart';
import 'package:devdesk/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('Settings theme toggle updates provider',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(
      container.read(themePreferencesProvider).brightnessMode,
      ThemeMode.light,
    );
  });

  testWidgets('Settings opens the complete Privacy Policy',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    await tester.pumpAndSettle();

    final policyTile = find.text('Privacy Policy');
    await tester.scrollUntilVisible(
      policyTile,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(policyTile);
    await tester.pumpAndSettle();

    expect(find.text('1. Who this policy covers'), findsOneWidget);
    expect(find.textContaining('Version 2026-07-22'), findsOneWidget);
  });
}
