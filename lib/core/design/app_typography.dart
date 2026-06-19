import 'package:flutter/material.dart';

class AppTypography {
  static const String monoFont = 'monospace';

  const AppTypography._();

  static TextStyle mono(BuildContext context, {double? fontSize}) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontFamily: monoFont,
      fontSize: fontSize ?? base.fontSize,
      height: 1.45,
    );
  }
}
