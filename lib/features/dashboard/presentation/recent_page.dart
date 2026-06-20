import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../provider/tool_providers.dart';
import 'widgets/tool_grid.dart';

class RecentPage extends ConsumerWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTools = ref.watch(recentToolsProvider);
    final favourites = ref.watch(favouritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Tools'),
      ),
      body: SafeArea(
        child: recentTools.isEmpty
            ? const AppEmptyState(
                icon: Icons.history,
                title: 'No recent tools',
                message: 'Your recently opened tools will appear here.',
              )
            : SingleChildScrollView(
                padding: AppSpacing.page(context),
                child: ToolGrid(
                  tools: recentTools,
                  favourites: favourites,
                  onOpenTool: (route) => _openTool(context, ref, route),
                  onToggleFavourite: (route) {
                    ref
                        .read(dashboardPrefsProvider.notifier)
                        .toggleFavourite(route);
                  },
                ),
              ),
      ),
    );
  }

  void _openTool(BuildContext context, WidgetRef ref, String route) {
    ref.read(dashboardPrefsProvider.notifier).markRecentlyUsed(route);
    Navigator.of(context).pushNamed(route);
  }
}
