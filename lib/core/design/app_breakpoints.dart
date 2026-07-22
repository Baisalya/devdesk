import 'package:flutter/widgets.dart';

class AppBreakpoints {
  /// Below this width the app remains usable but may intentionally simplify
  /// non-essential descriptions and secondary actions.
  static const double gracefulMinimum = 280;
  static const double narrow = 360;
  static const double compact = 600;
  static const double medium = 1024;

  const AppBreakpoints._();

  static bool isCompact(double width) => width < compact;

  static bool isNarrow(double width) => width < narrow;

  static bool isMedium(double width) => width >= compact && width < medium;

  static bool isExpanded(double width) => width >= medium;

  static DeviceClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (isCompact(width)) return DeviceClass.compact;
    if (isMedium(width)) return DeviceClass.medium;
    return DeviceClass.expanded;
  }
}

enum DeviceClass { compact, medium, expanded }
