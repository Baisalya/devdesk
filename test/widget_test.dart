import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/app/app.dart';
import 'package:devdesk/features/privacy/provider/privacy_acceptance_provider.dart';

void main() {
  testWidgets('DevDesk app loads dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyAcceptanceProvider.overrideWith(
            (ref) => PrivacyAcceptanceNotifier(
              loadOnCreate: false,
              initialState: const PrivacyAcceptanceState.accepted(),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DevDesk'), findsOneWidget);
    expect(find.text('Markdown Editor'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.shortcuts, isNotNull);
    expect(app.actions, isNotNull);
  });

  testWidgets('privacy gate disables global developer shortcuts',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyAcceptanceProvider.overrideWith(
            (ref) => PrivacyAcceptanceNotifier(
              loadOnCreate: false,
              initialState: const PrivacyAcceptanceState.required(),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy before you continue'), findsOneWidget);
    expect(find.text('Markdown Editor'), findsNothing);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.shortcuts, isNull);
    expect(app.actions, isNull);

    await tester.tap(find.byKey(const Key('read-full-privacy-policy')));
    await tester.pumpAndSettle();

    expect(find.text('1. Who this policy covers'), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy-back')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
