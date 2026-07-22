import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxHeight < 220 ||
            constraints.maxWidth < 280 ||
            textScale > 1.4;
        final padding = compact ? AppSpacing.sm : AppSpacing.xl;
        final content = Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 28 : 40, color: scheme.primary),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (action != null) ...[
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                action!,
              ],
            ],
          ),
        );

        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
