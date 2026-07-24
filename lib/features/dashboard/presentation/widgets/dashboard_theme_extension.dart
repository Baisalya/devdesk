import 'package:flutter/material.dart';

@immutable
class DashboardThemeExtension extends ThemeExtension<DashboardThemeExtension> {
  final Color workspaceAccent;
  final Color markdownAccent;
  final Color dataAccent;
  final Color apiAccent;
  final Color searchAccent;
  final Color securityAccent;
  final Color codeAccent;
  final Color gitAccent;
  final Color sidebarBackground;
  final Color cardGlow;

  const DashboardThemeExtension({
    required this.workspaceAccent,
    required this.markdownAccent,
    required this.dataAccent,
    required this.apiAccent,
    required this.searchAccent,
    required this.securityAccent,
    required this.codeAccent,
    required this.gitAccent,
    required this.sidebarBackground,
    required this.cardGlow,
  });

  factory DashboardThemeExtension.fromBrightness(
      Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;

    return DashboardThemeExtension(
      workspaceAccent: const Color(0xFF2563EB), // Blue
      markdownAccent: const Color(0xFFDB2777), // Pink
      dataAccent: const Color(0xFF16A34A), // Green
      apiAccent: const Color(0xFFEA580C), // Orange
      searchAccent: const Color(0xFF0891B2), // Cyan
      securityAccent: const Color(0xFF0F766E), // Teal
      codeAccent: const Color(0xFF4F46E5), // Indigo
      gitAccent: const Color(0xFFD97706), // Amber
      sidebarBackground:
          isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
      cardGlow: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
    );
  }

  @override
  DashboardThemeExtension copyWith({
    Color? workspaceAccent,
    Color? markdownAccent,
    Color? dataAccent,
    Color? apiAccent,
    Color? searchAccent,
    Color? securityAccent,
    Color? codeAccent,
    Color? gitAccent,
    Color? sidebarBackground,
    Color? cardGlow,
  }) {
    return DashboardThemeExtension(
      workspaceAccent: workspaceAccent ?? this.workspaceAccent,
      markdownAccent: markdownAccent ?? this.markdownAccent,
      dataAccent: dataAccent ?? this.dataAccent,
      apiAccent: apiAccent ?? this.apiAccent,
      searchAccent: searchAccent ?? this.searchAccent,
      securityAccent: securityAccent ?? this.securityAccent,
      codeAccent: codeAccent ?? this.codeAccent,
      gitAccent: gitAccent ?? this.gitAccent,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      cardGlow: cardGlow ?? this.cardGlow,
    );
  }

  @override
  DashboardThemeExtension lerp(
      ThemeExtension<DashboardThemeExtension>? other, double t) {
    if (other is! DashboardThemeExtension) return this;
    return DashboardThemeExtension(
      workspaceAccent: Color.lerp(workspaceAccent, other.workspaceAccent, t)!,
      markdownAccent: Color.lerp(markdownAccent, other.markdownAccent, t)!,
      dataAccent: Color.lerp(dataAccent, other.dataAccent, t)!,
      apiAccent: Color.lerp(apiAccent, other.apiAccent, t)!,
      searchAccent: Color.lerp(searchAccent, other.searchAccent, t)!,
      securityAccent: Color.lerp(securityAccent, other.securityAccent, t)!,
      codeAccent: Color.lerp(codeAccent, other.codeAccent, t)!,
      gitAccent: Color.lerp(gitAccent, other.gitAccent, t)!,
      sidebarBackground:
          Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      cardGlow: Color.lerp(cardGlow, other.cardGlow, t)!,
    );
  }

  static DashboardThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<DashboardThemeExtension>()!;
  }
}
