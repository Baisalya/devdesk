import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../domain/privacy_policy.dart';

enum PrivacyAcceptanceStatus { loading, required, accepted }

@immutable
class PrivacyAcceptanceState {
  final PrivacyAcceptanceStatus status;
  final bool isSaving;
  final String? errorMessage;

  const PrivacyAcceptanceState({
    required this.status,
    this.isSaving = false,
    this.errorMessage,
  });

  const PrivacyAcceptanceState.loading()
      : this(status: PrivacyAcceptanceStatus.loading);

  const PrivacyAcceptanceState.required({String? errorMessage})
      : this(
          status: PrivacyAcceptanceStatus.required,
          errorMessage: errorMessage,
        );

  const PrivacyAcceptanceState.accepted()
      : this(status: PrivacyAcceptanceStatus.accepted);

  bool get isAccepted => status == PrivacyAcceptanceStatus.accepted;

  PrivacyAcceptanceState copyWith({
    PrivacyAcceptanceStatus? status,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrivacyAcceptanceState(
      status: status ?? this.status,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class PrivacyAcceptanceStore {
  Future<Object?> read();

  Future<void> write(Map<String, String> value);
}

class LocalPrivacyAcceptanceStore implements PrivacyAcceptanceStore {
  static const String storageKey = 'privacy_policy_acceptance_v1';

  const LocalPrivacyAcceptanceStore();

  @override
  Future<Object?> read() async {
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    return box.get(storageKey);
  }

  @override
  Future<void> write(Map<String, String> value) async {
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await box.put(storageKey, value);
  }
}

final privacyAcceptanceProvider =
    StateNotifierProvider<PrivacyAcceptanceNotifier, PrivacyAcceptanceState>(
        (ref) {
  return PrivacyAcceptanceNotifier();
});

class PrivacyAcceptanceNotifier extends StateNotifier<PrivacyAcceptanceState> {
  final PrivacyAcceptanceStore _store;
  var _operation = 0;
  var _disposed = false;

  PrivacyAcceptanceNotifier({
    PrivacyAcceptanceStore store = const LocalPrivacyAcceptanceStore(),
    bool loadOnCreate = true,
    PrivacyAcceptanceState initialState =
        const PrivacyAcceptanceState.loading(),
  })  : _store = store,
        super(initialState) {
    if (loadOnCreate) load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final operation = ++_operation;
    try {
      final stored = await _store.read();
      if (_disposed || operation != _operation) return;
      final map = stored is Map ? stored : const <Object?, Object?>{};
      final acceptedVersion = map['policyVersion'];
      state = acceptedVersion == DevDeskPrivacyPolicy.version
          ? const PrivacyAcceptanceState.accepted()
          : const PrivacyAcceptanceState.required();
    } catch (error, stackTrace) {
      debugPrint('Privacy acceptance could not be loaded: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!_disposed && operation == _operation) {
        state = const PrivacyAcceptanceState.required(
          errorMessage:
              'Privacy acceptance could not be read. Review the policy and try again.',
        );
      }
    }
  }

  Future<bool> accept() async {
    if (_disposed || state.isSaving) return false;
    final operation = ++_operation;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _store.write({
        'policyVersion': DevDeskPrivacyPolicy.version,
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (_disposed || operation != _operation) return false;
      state = const PrivacyAcceptanceState.accepted();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Privacy acceptance could not be saved: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!_disposed && operation == _operation) {
        state = const PrivacyAcceptanceState.required(
          errorMessage:
              'Acceptance could not be saved on this device. Check local storage and try again.',
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}
