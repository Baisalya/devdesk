import 'package:flutter/material.dart';

@immutable
class DevDeskSemanticColors extends ThemeExtension<DevDeskSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color favorite;
  final Color codeSurface;
  final Color diffAdded;
  final Color diffRemoved;
  final Color diffModified;
  final Color pro;

  const DevDeskSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.favorite,
    required this.codeSurface,
    required this.diffAdded,
    required this.diffRemoved,
    required this.diffModified,
    required this.pro,
  });

  factory DevDeskSemanticColors.fromScheme(
    ColorScheme scheme, {
    required bool highContrast,
  }) {
    ColorScheme semanticScheme(Color seed) {
      return ColorScheme.fromSeed(
        seedColor: seed,
        brightness: scheme.brightness,
        contrastLevel: highContrast ? 1 : 0.25,
      );
    }

    final success = semanticScheme(const Color(0xFF15803D));
    final warning = semanticScheme(const Color(0xFFB45309));
    final info = semanticScheme(const Color(0xFF0369A1));
    final favorite = semanticScheme(const Color(0xFFEAB308));

    return DevDeskSemanticColors(
      success: success.primary,
      onSuccess: success.onPrimary,
      successContainer: success.primaryContainer,
      onSuccessContainer: success.onPrimaryContainer,
      warning: warning.primary,
      onWarning: warning.onPrimary,
      warningContainer: warning.primaryContainer,
      onWarningContainer: warning.onPrimaryContainer,
      info: info.primary,
      onInfo: info.onPrimary,
      infoContainer: info.primaryContainer,
      onInfoContainer: info.onPrimaryContainer,
      favorite: favorite.primary,
      codeSurface: Color.alphaBlend(
        scheme.primary.withValues(
          alpha: scheme.brightness == Brightness.dark ? 0.06 : 0.025,
        ),
        scheme.surfaceContainerLowest,
      ),
      diffAdded: success.primary,
      diffRemoved: scheme.error,
      diffModified: warning.primary,
      pro: scheme.tertiary,
    );
  }

  static DevDeskSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<DevDeskSemanticColors>() ??
        DevDeskSemanticColors.fromScheme(
          theme.colorScheme,
          highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
        );
  }

  @override
  DevDeskSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? favorite,
    Color? codeSurface,
    Color? diffAdded,
    Color? diffRemoved,
    Color? diffModified,
    Color? pro,
  }) {
    return DevDeskSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      favorite: favorite ?? this.favorite,
      codeSurface: codeSurface ?? this.codeSurface,
      diffAdded: diffAdded ?? this.diffAdded,
      diffRemoved: diffRemoved ?? this.diffRemoved,
      diffModified: diffModified ?? this.diffModified,
      pro: pro ?? this.pro,
    );
  }

  @override
  DevDeskSemanticColors lerp(
    covariant DevDeskSemanticColors? other,
    double t,
  ) {
    if (other == null) return this;
    return DevDeskSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      codeSurface: Color.lerp(codeSurface, other.codeSurface, t)!,
      diffAdded: Color.lerp(diffAdded, other.diffAdded, t)!,
      diffRemoved: Color.lerp(diffRemoved, other.diffRemoved, t)!,
      diffModified: Color.lerp(diffModified, other.diffModified, t)!,
      pro: Color.lerp(pro, other.pro, t)!,
    );
  }
}
