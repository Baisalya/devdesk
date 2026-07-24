import 'package:flutter/material.dart';
import '../../../../core/design/app_spacing.dart';
import 'dashboard_search_field.dart';

class DashboardTopHeader extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool isSearchActive;
  final VoidCallback onToggleTheme;
  final Brightness currentBrightness;

  const DashboardTopHeader({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.isSearchActive,
    required this.onToggleTheme,
    required this.currentBrightness,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome back, Dev! 👋',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Everything you need for offline development, organised and ready.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isNarrow) ...[
                    _HeaderAction(
                      icon: currentBrightness == Brightness.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      onPressed: onToggleTheme,
                      tooltip: 'Toggle Theme',
                    ),
                  ] else ...[
                    const SizedBox(width: AppSpacing.md),
                    _HeaderAction(
                      icon: currentBrightness == Brightness.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      onPressed: onToggleTheme,
                      tooltip: 'Toggle Theme',
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _HeaderAction(
                      icon: Icons.notifications_none_rounded,
                      onPressed: () {},
                      tooltip: 'Notifications',
                      badgeCount: 3,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: isNarrow ? double.infinity : 400,
                child: DashboardSearchField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final int badgeCount;

  const _HeaderAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          tooltip: tooltip,
        ),
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
