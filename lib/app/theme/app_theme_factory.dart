import 'package:flutter/material.dart';

import '../../core/design/app_radius.dart';
import '../../core/design/app_spacing.dart';
import 'app_palette.dart';
import '../../features/dashboard/presentation/widgets/dashboard_theme_extension.dart';
import 'devdesk_semantic_colors.dart';
import 'theme_preferences.dart';

class AppThemeFactory {
  const AppThemeFactory._();

  static ThemeData build({
    required AppPalette palette,
    required Brightness brightness,
    required AppContrastMode contrastMode,
    required AppDensityMode densityMode,
  }) {
    final highContrast = contrastMode == AppContrastMode.high;
    final generated = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    final surface = palette.surface(brightness);
    final scheme = generated.copyWith(
      surface: surface,
      surfaceContainerLowest: _blend(surface, generated.primary, 0.015),
      surfaceContainerLow: _blend(surface, generated.primary, 0.035),
      surfaceContainer: _blend(surface, generated.primary, 0.055),
      surfaceContainerHigh: _blend(surface, generated.primary, 0.08),
      surfaceContainerHighest: _blend(surface, generated.primary, 0.11),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: densityMode == AppDensityMode.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          focusColor: scheme.primary.withValues(alpha: 0.16),
          hoverColor: scheme.primary.withValues(alpha: 0.08),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.small),
          ),
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.small),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.small,
        ),
        textStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(
          alpha: brightness == Brightness.dark ? 0.28 : 0.22,
        ),
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
      extensions: [
        DevDeskSemanticColors.fromScheme(
          scheme,
          highContrast: highContrast,
        ),
        DashboardThemeExtension.fromBrightness(brightness, scheme),
      ],
    );
  }

  static Color _blend(Color surface, Color tint, double amount) {
    return Color.alphaBlend(tint.withValues(alpha: amount), surface);
  }
}
