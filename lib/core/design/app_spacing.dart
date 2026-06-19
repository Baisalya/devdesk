import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  const AppSpacing._();

  static EdgeInsets page(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (AppBreakpoints.isExpanded(width)) {
      return const EdgeInsets.all(xxl);
    }
    if (AppBreakpoints.isMedium(width)) {
      return const EdgeInsets.all(xl);
    }
    return const EdgeInsets.all(md);
  }

  static double pageValue(BuildContext context) => page(context).left;
}
