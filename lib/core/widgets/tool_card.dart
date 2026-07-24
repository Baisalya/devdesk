import 'package:flutter/material.dart';

import '../../core/constants/tool_list.dart';
import '../../features/dashboard/presentation/widgets/dashboard_theme_extension.dart';
import '../design/app_spacing.dart';
import 'app_card.dart';

/// A clickable card representing a [DevTool] on the dashboard.
class ToolCard extends StatefulWidget {
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
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dashboardColors = DashboardThemeExtension.of(context);

    final accentColor = _getAccentColor(widget.tool, dashboardColors);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AppCard(
          onTap: widget.onTap,
          padding: EdgeInsets.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: _isHovered
                  ? LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.1),
                        accentColor.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: _isHovered
                  ? Border.all(
                      color: accentColor.withValues(alpha: 0.3), width: 1)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding:
                  EdgeInsets.all(widget.dense ? AppSpacing.sm : AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.tool.icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.tool.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.tool.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: widget.dense ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onFavouritePressed != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: Icon(
                        widget.favourite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 20,
                      ),
                      color: widget.favourite
                          ? Colors.amber
                          : scheme.onSurfaceVariant,
                      tooltip: widget.favourite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      onPressed: widget.onFavouritePressed,
                    ),
                  ],
                  if (_isHovered)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getAccentColor(DevTool tool, DashboardThemeExtension colors) {
    final route = tool.route.toLowerCase();
    if (route.contains('workspace')) {
      return colors.workspaceAccent;
    }
    if (route.contains('vault') ||
        route.contains('markdown') ||
        route.contains('readme')) {
      return colors.markdownAccent;
    }
    if (route.contains('json')) {
      return colors.dataAccent;
    }
    if (route.contains('api') || route.contains('openapi')) {
      return colors.apiAccent;
    }
    if (route.contains('search')) {
      return colors.searchAccent;
    }
    if (route.contains('jwt')) {
      return colors.securityAccent;
    }
    if (route.contains('regex') ||
        route.contains('base64') ||
        route.contains('url') ||
        route.contains('timestamp') ||
        route.contains('uuid') ||
        route.contains('snippets')) {
      return colors.codeAccent;
    }
    if (route.contains('diff')) {
      return colors.gitAccent;
    }
    return colors.workspaceAccent;
  }
}
