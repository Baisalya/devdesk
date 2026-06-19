import 'package:flutter/widgets.dart';

class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;

  const AppBreakpoints._();

  static bool isCompact(double width) => width < compact;

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
