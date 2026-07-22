import 'package:flutter/material.dart';

import 'app_palette.dart';

enum AppContrastMode { system, standard, high }

enum AppDensityMode { comfortable, compact }

@immutable
class ThemePreferences {
  static const int schemaVersion = 1;

  final ThemeMode brightnessMode;
  final AppPalette palette;
  final AppContrastMode contrastMode;
  final AppDensityMode densityMode;
  final String codeThemeId;

  const ThemePreferences({
    this.brightnessMode = ThemeMode.system,
    this.palette = AppPalette.devdeskOcean,
    this.contrastMode = AppContrastMode.system,
    this.densityMode = AppDensityMode.comfortable,
    this.codeThemeId = 'adaptive',
  });

  ThemePreferences copyWith({
    ThemeMode? brightnessMode,
    AppPalette? palette,
    AppContrastMode? contrastMode,
    AppDensityMode? densityMode,
    String? codeThemeId,
  }) {
    return ThemePreferences(
      brightnessMode: brightnessMode ?? this.brightnessMode,
      palette: palette ?? this.palette,
      contrastMode: contrastMode ?? this.contrastMode,
      densityMode: densityMode ?? this.densityMode,
      codeThemeId: codeThemeId ?? this.codeThemeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'brightnessMode': brightnessMode.name,
      'paletteId': palette.id,
      'contrastMode': contrastMode.name,
      'densityMode': densityMode.name,
      'codeThemeId': codeThemeId,
    };
  }

  factory ThemePreferences.fromMap(Map<dynamic, dynamic> map) {
    return ThemePreferences(
      brightnessMode: _themeMode(map['brightnessMode']),
      palette: AppPalette.fromId(map['paletteId'] as String?),
      contrastMode: _enumByName(
        AppContrastMode.values,
        map['contrastMode'],
        AppContrastMode.system,
      ),
      densityMode: _enumByName(
        AppDensityMode.values,
        map['densityMode'],
        AppDensityMode.comfortable,
      ),
      codeThemeId: map['codeThemeId'] is String
          ? map['codeThemeId'] as String
          : 'adaptive',
    );
  }

  static ThemeMode _themeMode(dynamic value) {
    return _enumByName(ThemeMode.values, value, ThemeMode.system);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    dynamic raw,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}
