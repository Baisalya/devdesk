import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/privacy/presentation/privacy_acceptance_gate.dart';
import 'package:devdesk/features/privacy/provider/privacy_acceptance_provider.dart';

void main() {
  testWidgets('gate blocks app content until affirmative acceptance',
      (tester) async {
    final store = _MemoryStore();
    final notifier = PrivacyAcceptanceNotifier(
      store: store,
      loadOnCreate: false,
      initialState: const PrivacyAcceptanceState.required(),
    );
    await _pumpGate(tester, notifier);

    expect(find.text('Privacy before you continue'), findsOneWidget);
    expect(find.text('Developer tools are available'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(
            const Key('accept-privacy-policy'),
          ))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('read-full-privacy-policy')));
    await tester.pumpAndSettle();
    expect(find.text('1. Who this policy covers'), findsOneWidget);

    await tester.tap(find.byKey(const Key('privacy-policy-back')));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(const Key('privacy-acceptance-checkbox'));
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(
            const Key('accept-privacy-policy'),
          ))
          .onPressed,
      isNotNull,
    );

    final acceptButton = find.byKey(const Key('accept-privacy-policy'));
    await tester.ensureVisible(acceptButton);
    await tester.pumpAndSettle();
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(find.text('Developer tools are available'), findsOneWidget);
    expect(store.value, isNotNull);
  });

  testWidgets('gate remains visible when acceptance cannot be saved',
      (tester) async {
    final notifier = PrivacyAcceptanceNotifier(
      store: _MemoryStore()..failWrite = true,
      loadOnCreate: false,
      initialState: const PrivacyAcceptanceState.required(),
    );
    await _pumpGate(tester, notifier);

    final checkbox = find.byKey(const Key('privacy-acceptance-checkbox'));
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pump();
    final acceptButton = find.byKey(const Key('accept-privacy-policy'));
    await tester.ensureVisible(acceptButton);
    await tester.pumpAndSettle();
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(find.text('Privacy before you continue'), findsOneWidget);
    expect(
        find.textContaining('Acceptance could not be saved'), findsOneWidget);
    expect(find.text('Developer tools are available'), findsNothing);
  });

  testWidgets('gate is scroll-safe at 280 px and 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = PrivacyAcceptanceNotifier(
      store: _MemoryStore(),
      loadOnCreate: false,
      initialState: const PrivacyAcceptanceState.required(),
    );
    await _pumpGate(tester, notifier, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('privacy-acceptance-scroll-view')),
        findsOneWidget);
    expect(find.text('Privacy before you continue'), findsOneWidget);
  });
}

Future<void> _pumpGate(
  WidgetTester tester,
  PrivacyAcceptanceNotifier notifier, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyAcceptanceProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        ),
        home: PrivacyAcceptanceGate(
          child: const Scaffold(
            body: Center(child: Text('Developer tools are available')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryStore implements PrivacyAcceptanceStore {
  Object? value;
  bool failWrite = false;

  @override
  Future<Object?> read() async => value;

  @override
  Future<void> write(Map<String, String> value) async {
    if (failWrite) throw StateError('storage unavailable');
    this.value = Map<String, String>.from(value);
  }
}
