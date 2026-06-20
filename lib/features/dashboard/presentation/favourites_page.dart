import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tool_list.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../provider/tool_providers.dart';
import 'widgets/tool_grid.dart';

class FavouritesPage extends ConsumerWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritesProvider);
    final favouriteTools =
        tools.where((tool) => favourites.contains(tool.route)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
      ),
      body: SafeArea(
        child: favouriteTools.isEmpty
            ? const AppEmptyState(
                icon: Icons.star_outline,
                title: 'No favourites yet',
                message: 'Tap the star on any tool to pin it here.',
              )
            : SingleChildScrollView(
                padding: AppSpacing.page(context),
                child: ToolGrid(
                  tools: favouriteTools,
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
