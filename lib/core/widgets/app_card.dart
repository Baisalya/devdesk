import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../design/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool filled;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
    return Material(
      color: filled ? scheme.surfaceContainerLow : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              hoverColor: scheme.primary.withValues(alpha: 0.05),
              child: content,
            ),
    );
  }
}
