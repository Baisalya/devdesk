import 'package:flutter/material.dart';

import '../../core/constants/tool_list.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import 'app_card.dart';

/// A clickable card representing a [DevTool] on the dashboard.
class ToolCard extends StatelessWidget {
  final DevTool tool;
  final VoidCallback onTap;
  final bool favourite;
  final VoidCallback? onFavouritePressed;
  final bool dense;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.favourite = false,
    this.onFavouritePressed,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tool.icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!dense) ...[
                    const SizedBox(height: 3),
                    Text(
                      tool.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (onFavouritePressed != null) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: Icon(favourite ? Icons.star : Icons.star_border),
                color: favourite ? AppColors.favorite(context) : null,
                tooltip:
                    favourite ? 'Remove from favourites' : 'Add to favourites',
                onPressed: onFavouritePressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
