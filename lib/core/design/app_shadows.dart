import 'package:flutter/material.dart';

class AppShadows {
  static List<BoxShadow> soft(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.18 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  const AppShadows._();
}
