import 'package:flutter/material.dart';

import '../design/app_radius.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.secondaryContainer,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: effectiveColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
