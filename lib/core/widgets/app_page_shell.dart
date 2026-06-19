import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

class AppPageShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const AppPageShell({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? AppSpacing.page(context),
      child: child,
    );
    if (!scrollable) return content;
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: content,
      ),
    );
  }
}
