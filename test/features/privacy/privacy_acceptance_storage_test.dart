import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/privacy/provider/privacy_acceptance_provider.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('devdesk_privacy_test');
    LocalStorage.initializeForTest(directory.path);
  });

  setUp(() => LocalStorage.clearAll());

  tearDownAll(() async {
    await LocalStorage.closeAll();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('local acceptance survives restart and Clear All Data removes it',
      () async {
    final first = PrivacyAcceptanceNotifier();
    addTearDown(first.dispose);
    await _waitUntil(
      () => first.state.status == PrivacyAcceptanceStatus.required,
    );
    expect(await first.accept(), isTrue);

    final restored = PrivacyAcceptanceNotifier();
    addTearDown(restored.dispose);
    await _waitUntil(
      () => restored.state.status != PrivacyAcceptanceStatus.loading,
    );
    expect(restored.state.status, PrivacyAcceptanceStatus.accepted);

    await LocalStorage.clearAll();
    final afterClear = PrivacyAcceptanceNotifier();
    addTearDown(afterClear.dispose);
    await _waitUntil(
      () => afterClear.state.status != PrivacyAcceptanceStatus.loading,
    );
    expect(afterClear.state.status, PrivacyAcceptanceStatus.required);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before timeout.');
}
