import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage.dart';
import 'app_palette.dart';
import 'theme_preferences.dart';

final themePreferencesProvider =
    StateNotifierProvider<ThemePreferencesNotifier, ThemePreferences>((ref) {
  return ThemePreferencesNotifier();
});

class ThemePreferencesNotifier extends StateNotifier<ThemePreferences> {
  ThemePreferencesNotifier() : super(const ThemePreferences()) {
    _load();
  }

  static const _storageKey = 'theme_preferences_v1';
  static const _legacyThemeModeKey = 'theme_mode';
  var _localMutation = 0;

  Future<void> _load() async {
    final mutationAtStart = _localMutation;
    try {
      final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
      final stored = box.get(_storageKey);
      final loaded = stored is Map
          ? ThemePreferences.fromMap(stored)
          : ThemePreferences(
              brightnessMode: _legacyThemeMode(
                box.get(_legacyThemeModeKey) as String?,
              ),
            );
      if (mutationAtStart == _localMutation) state = loaded;
    } catch (error, stackTrace) {
      debugPrint('Theme preferences could not be loaded: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setBrightnessMode(ThemeMode mode) {
    return _update(state.copyWith(brightnessMode: mode));
  }

  Future<void> setPalette(AppPalette palette) {
    return _update(state.copyWith(palette: palette));
  }

  Future<void> setContrastMode(AppContrastMode mode) {
    return _update(state.copyWith(contrastMode: mode));
  }

  Future<void> setDensityMode(AppDensityMode mode) {
    return _update(state.copyWith(densityMode: mode));
  }

  Future<void> reset() => _update(const ThemePreferences());

  Future<void> _update(ThemePreferences next) async {
    _localMutation++;
    state = next;
    try {
      final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
      await box.put(_storageKey, next.toMap());
      await box.put(_legacyThemeModeKey, next.brightnessMode.name);
    } catch (error, stackTrace) {
      debugPrint('Theme preferences could not be saved: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static ThemeMode _legacyThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
