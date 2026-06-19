import 'package:flutter/material.dart';

import '../design/app_breakpoints.dart';
import '../design/app_spacing.dart';

class AppDesktopSplitView extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final double primaryFlex;
  final double secondaryFlex;
  final double breakpoint;
  final double gap;

  const AppDesktopSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.breakpoint = AppBreakpoints.medium,
    this.gap = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: (primaryFlex * 100).round(), child: primary),
              SizedBox(width: gap),
              Expanded(flex: (secondaryFlex * 100).round(), child: secondary),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: primary),
            SizedBox(height: gap),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}
