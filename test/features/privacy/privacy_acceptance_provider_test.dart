import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/privacy/domain/privacy_policy.dart';
import 'package:devdesk/features/privacy/provider/privacy_acceptance_provider.dart';

void main() {
  test('a fresh installation requires privacy acceptance', () async {
    final notifier = PrivacyAcceptanceNotifier(store: _MemoryStore());
    addTearDown(notifier.dispose);

    await _waitUntil(
      () => notifier.state.status != PrivacyAcceptanceStatus.loading,
    );

    expect(notifier.state.status, PrivacyAcceptanceStatus.required);
  });

  test('acceptance persists the current policy version and UTC time', () async {
    final store = _MemoryStore();
    final notifier = PrivacyAcceptanceNotifier(store: store);
    addTearDown(notifier.dispose);
    await _waitUntil(
      () => notifier.state.status == PrivacyAcceptanceStatus.required,
    );

    expect(await notifier.accept(), isTrue);
    expect(notifier.state.status, PrivacyAcceptanceStatus.accepted);
    expect(
      (store.value as Map)['policyVersion'],
      DevDeskPrivacyPolicy.version,
    );
    expect(
      DateTime.parse((store.value as Map)['acceptedAt'] as String).isUtc,
      isTrue,
    );
  });

  test('the current version restores as accepted', () async {
    final notifier = PrivacyAcceptanceNotifier(
      store: _MemoryStore({
        'policyVersion': DevDeskPrivacyPolicy.version,
        'acceptedAt': '2026-07-22T00:00:00.000Z',
      }),
    );
    addTearDown(notifier.dispose);

    await _waitUntil(
      () => notifier.state.status != PrivacyAcceptanceStatus.loading,
    );

    expect(notifier.state.status, PrivacyAcceptanceStatus.accepted);
  });

  test('an older accepted policy requires acknowledgement again', () async {
    final notifier = PrivacyAcceptanceNotifier(
      store: _MemoryStore({
        'policyVersion': '2026-07-01',
        'acceptedAt': '2026-07-01T00:00:00.000Z',
      }),
    );
    addTearDown(notifier.dispose);

    await _waitUntil(
      () => notifier.state.status != PrivacyAcceptanceStatus.loading,
    );

    expect(notifier.state.status, PrivacyAcceptanceStatus.required);
  });

  test('a storage failure keeps the gate closed and reports an error',
      () async {
    final store = _MemoryStore()..failWrite = true;
    final notifier = PrivacyAcceptanceNotifier(store: store);
    addTearDown(notifier.dispose);
    await _waitUntil(
      () => notifier.state.status == PrivacyAcceptanceStatus.required,
    );

    expect(await notifier.accept(), isFalse);
    expect(notifier.state.status, PrivacyAcceptanceStatus.required);
    expect(notifier.state.errorMessage, isNotEmpty);
  });
}

class _MemoryStore implements PrivacyAcceptanceStore {
  Object? value;
  bool failWrite = false;

  _MemoryStore([this.value]);

  @override
  Future<Object?> read() async => value;

  @override
  Future<void> write(Map<String, String> value) async {
    if (failWrite) throw StateError('storage unavailable');
    this.value = Map<String, String>.from(value);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before timeout.');
}
