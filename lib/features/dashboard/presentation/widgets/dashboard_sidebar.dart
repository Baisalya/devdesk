import 'package:flutter/material.dart';
import '../../../../core/design/app_spacing.dart';
import 'dashboard_theme_extension.dart';

class DashboardSidebar extends StatelessWidget {
  final String selectedRoute;
  final ValueChanged<String> onRouteSelected;

  const DashboardSidebar({
    super.key,
    required this.selectedRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dashboardColors = DashboardThemeExtension.of(context);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: dashboardColors.sidebarBackground,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.developer_mode_rounded,
                    color: scheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DevDesk',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Offline Workspace',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/dashboard',
                  selected: selectedRoute == '/dashboard',
                  onTap: () => onRouteSelected('/dashboard'),
                ),
                _SidebarItem(
                  icon: Icons.workspaces_outline,
                  label: 'Workspaces',
                  route: '/workspaces',
                  selected: selectedRoute == '/workspaces',
                  onTap: () => onRouteSelected('/workspaces'),
                ),
                _SidebarItem(
                  icon: Icons.api_rounded,
                  label: 'API Lab',
                  route: '/api',
                  selected: selectedRoute == '/api',
                  onTap: () => onRouteSelected('/api'),
                ),
                _SidebarItem(
                  icon: Icons.article_outlined,
                  label: 'Markdown',
                  route: '/vault',
                  selected: selectedRoute == '/vault',
                  onTap: () => onRouteSelected('/vault'),
                ),
                _SidebarItem(
                  icon: Icons.data_object_rounded,
                  label: 'Data Tools',
                  route: '/json',
                  selected: selectedRoute == '/json',
                  onTap: () => onRouteSelected('/json'),
                ),
                _SidebarItem(
                  icon: Icons.code_rounded,
                  label: 'Snippets',
                  route: '/snippets',
                  selected: selectedRoute == '/snippets',
                  onTap: () => onRouteSelected('/snippets'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(),
                ),
                _SidebarItem(
                  icon: Icons.manage_search_rounded,
                  label: 'Unified Search',
                  route: '/search',
                  selected: selectedRoute == '/search',
                  onTap: () => onRouteSelected('/search'),
                ),
                _SidebarItem(
                  icon: Icons.history_rounded,
                  label: 'Recent',
                  route: '/recent',
                  selected: selectedRoute == '/recent',
                  onTap: () => onRouteSelected('/recent'),
                ),
                _SidebarItem(
                  icon: Icons.star_outline_rounded,
                  label: 'Favourites',
                  route: '/favourites',
                  selected: selectedRoute == '/favourites',
                  onTap: () => onRouteSelected('/favourites'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _SidebarItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              route: '/settings',
              selected: selectedRoute == '/settings',
              onTap: () => onRouteSelected('/settings'),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '100% Offline & Private',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
