import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/app/theme/app_palette.dart';
import 'package:devdesk/app/theme/app_theme_factory.dart';
import 'package:devdesk/app/theme/devdesk_semantic_colors.dart';
import 'package:devdesk/app/theme/theme_controller.dart';
import 'package:devdesk/app/theme/theme_preferences.dart';
import 'package:devdesk/core/storage/local_storage.dart';

void main() {
  group('ThemePreferences', () {
    test('round-trips every persisted appearance choice', () {
      const preferences = ThemePreferences(
        brightnessMode: ThemeMode.dark,
        palette: AppPalette.neonViolet,
        contrastMode: AppContrastMode.high,
        densityMode: AppDensityMode.compact,
        codeThemeId: 'adaptive',
      );

      expect(ThemePreferences.fromMap(preferences.toMap()).toMap(),
          preferences.toMap());
    });

    test('falls back safely when stored values are unknown', () {
      final preferences = ThemePreferences.fromMap(const {
        'brightnessMode': 'future-mode',
        'paletteId': 'removed-palette',
        'contrastMode': 7,
        'densityMode': null,
      });

      expect(preferences, isA<ThemePreferences>());
      expect(preferences.brightnessMode, ThemeMode.system);
      expect(preferences.palette, AppPalette.devdeskOcean);
      expect(preferences.contrastMode, AppContrastMode.system);
      expect(preferences.densityMode, AppDensityMode.comfortable);
    });
  });

  group('AppThemeFactory', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        test('${palette.label} builds an accessible ${brightness.name} theme',
            () {
          final standard = AppThemeFactory.build(
            palette: palette,
            brightness: brightness,
            contrastMode: AppContrastMode.standard,
            densityMode: AppDensityMode.comfortable,
          );
          final high = AppThemeFactory.build(
            palette: palette,
            brightness: brightness,
            contrastMode: AppContrastMode.high,
            densityMode: AppDensityMode.compact,
          );

          expect(standard.brightness, brightness);
          expect(standard.extension<DevDeskSemanticColors>(), isNotNull);
          expect(
            _contrastRatio(
              standard.colorScheme.onSurface,
              standard.colorScheme.surface,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrastRatio(
              high.colorScheme.onSurface,
              high.colorScheme.surface,
            ),
            greaterThanOrEqualTo(
              _contrastRatio(
                standard.colorScheme.onSurface,
                standard.colorScheme.surface,
              ),
            ),
          );
          expect(high.visualDensity, VisualDensity.compact);
        });
      }
    }
  });

  group('ThemePreferencesNotifier persistence', () {
    late Directory directory;

    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('devdesk_theme_test');
      LocalStorage.initializeForTest(directory.path);
    });

    setUp(() async {
      await LocalStorage.clearAll();
    });

    tearDownAll(() async {
      await LocalStorage.closeAll();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    test('migrates legacy brightness and persists the new schema', () async {
      final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
      await box.put('theme_mode', 'dark');

      final notifier = ThemePreferencesNotifier();
      addTearDown(notifier.dispose);
      await _waitUntil(
        () => notifier.state.brightnessMode == ThemeMode.dark,
      );

      expect(notifier.state.palette, AppPalette.devdeskOcean);
      await notifier.setPalette(AppPalette.graphiteMono);
      await notifier.setContrastMode(AppContrastMode.high);
      await notifier.setDensityMode(AppDensityMode.compact);

      final stored = box.get('theme_preferences_v1');
      expect(stored, isA<Map>());
      final restored = ThemePreferences.fromMap(stored as Map);
      expect(restored.brightnessMode, ThemeMode.dark);
      expect(restored.palette, AppPalette.graphiteMono);
      expect(restored.contrastMode, AppContrastMode.high);
      expect(restored.densityMode, AppDensityMode.compact);
      expect(box.get('theme_mode'), 'dark');
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before timeout.');
}
