import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workspaces/provider/workspace_provider.dart';
import '../../provider/tool_providers.dart';

class DashboardStatsPanel extends ConsumerWidget {
  const DashboardStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final toolCount = ref.watch(filteredToolsProvider).length;
    final favCount = ref.watch(favouritesProvider).length;
    final recentCount = ref.watch(recentToolsProvider).length;
    final workspaceCount =
        ref.watch(workspaceRegistryProvider).workspaces.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final recentWorkspaces = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Workspaces',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/recent'),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            isNarrow
                ? Column(
                    children: [
                      _RecentWorkspaceCard(
                        name: 'Dev APIs',
                        path: 'C:/Projects/DevAPIs',
                        timeAgo: '2h ago',
                        icon: Icons.folder_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RecentWorkspaceCard(
                        name: 'My Notes',
                        path: 'C:/Notes',
                        timeAgo: '5h ago',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RecentWorkspaceCard(
                        name: 'Web Project',
                        path: 'D:/WebProject',
                        timeAgo: '1d ago',
                        icon: Icons.code_rounded,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _RecentWorkspaceCard(
                        name: 'Dev APIs',
                        path: 'C:/Projects/DevAPIs',
                        timeAgo: '2h ago',
                        icon: Icons.folder_rounded,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _RecentWorkspaceCard(
                        name: 'My Notes',
                        path: 'C:/Notes',
                        timeAgo: '5h ago',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _RecentWorkspaceCard(
                        name: 'Web Project',
                        path: 'D:/WebProject',
                        timeAgo: '1d ago',
                        icon: Icons.code_rounded,
                      ),
                    ],
                  ),
          ],
        );

        final quickStats = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Stats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _LiveBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _StatItem(
                    icon: Icons.workspaces_rounded,
                    label: 'Workspaces',
                    value: '$workspaceCount',
                    color: Colors.blue,
                  ),
                  const Divider(height: AppSpacing.xl),
                  _StatItem(
                    icon: Icons.description_rounded,
                    label: 'Tools Available',
                    value: '$toolCount',
                    color: Colors.cyan,
                  ),
                  const Divider(height: AppSpacing.xl),
                  _StatItem(
                    icon: Icons.bolt_rounded,
                    label: 'Favorites',
                    value: '$favCount',
                    color: Colors.purple,
                  ),
                  const Divider(height: AppSpacing.xl),
                  _StatItem(
                    icon: Icons.data_object_rounded,
                    label: 'Recently Used',
                    value: '$recentCount',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            children: [
              recentWorkspaces,
              const SizedBox(height: AppSpacing.xxl),
              quickStats,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: recentWorkspaces),
            const SizedBox(width: AppSpacing.xl),
            Expanded(flex: 1, child: quickStats),
          ],
        );
      },
    );
  }
}

class _RecentWorkspaceCard extends StatelessWidget {
  final String name;
  final String path;
  final String timeAgo;
  final IconData icon;

  const _RecentWorkspaceCard({
    required this.name,
    required this.path,
    required this.timeAgo,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      flex: MediaQuery.sizeOf(context).width < 800 ? 0 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              path,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
