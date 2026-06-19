import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/design/app_spacing.dart';

/// Defines the dark Material 3 theme for the application.
final ColorScheme _darkScheme = ColorScheme.fromSeed(
  seedColor: AppColors.seed,
  brightness: Brightness.dark,
);

final ThemeData darkTheme = _buildTheme(_darkScheme);

ThemeData _buildTheme(ColorScheme scheme) {
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: const Color(0xFF0B0F14),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: const Color(0xFF0B0F14),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: AppRadius.small,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.small,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.small,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.small,
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: scheme.primary,
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged);
      }),
      radius: const Radius.circular(AppRadius.sm),
      thickness: WidgetStateProperty.all(8),
    ),
  );
}
