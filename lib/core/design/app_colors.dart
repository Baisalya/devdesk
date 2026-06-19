import 'package:flutter/material.dart';

class AppColors {
  static const Color seed = Color(0xFF2563EB);
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color info = Color(0xFF0369A1);
  static const Color destructive = Color(0xFFB91C1C);

  const AppColors._();

  static Color successContainer(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF12351F) : const Color(0xFFDFF7E7);
  }

  static Color warningContainer(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF3A2A11) : const Color(0xFFFFF3D6);
  }

  static Color infoContainer(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF102F46) : const Color(0xFFE1F2FF);
  }

  static Color codeBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF101418) : scheme.surfaceContainerLowest;
  }
}
