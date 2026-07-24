import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../rating/provider/rating_service.dart';
import '../provider/tool_providers.dart';
import 'widgets/dashboard_shell.dart';
import 'widgets/dashboard_stats_panel.dart';
import 'widgets/dashboard_top_header.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/tool_grid.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(
        ref.read(ratingServiceProvider).showRateDialogIfMeetsCriteria(context),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _openRoute(String route) {
    if (route == '/dashboard') return;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = ref.watch(filteredToolsProvider);
    final favourites = ref.watch(favouritesProvider);
    final query = ref.watch(searchQueryProvider);
    final themePref = ref.watch(themePreferencesProvider);

    final hasSearchQuery = query.trim().isNotEmpty;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _SearchIntent(),
      },
      child: Actions(
        actions: {
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) => _searchFocusNode.requestFocus(),
          ),
        },
        child: DevDeskDashboardShell(
          selectedRoute: '/dashboard',
          onRouteSelected: _openRoute,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardTopHeader(
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onSearchChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                    onClearSearch: _clearSearch,
                    isSearchActive: true,
                    onToggleTheme: () {
                      final next = themePref.brightnessMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                      ref
                          .read(themePreferencesProvider.notifier)
                          .setBrightnessMode(next);
                    },
                    currentBrightness: Theme.of(context).brightness,
                  ),
                  if (!hasSearchQuery) ...[
                    QuickActionsSection(
                      onOpenFile: () => _openExternalFile(context, ref),
                      onOpenApi: () => _openTool(context, ref, '/api'),
                      onOpenJson: () => _openTool(context, ref, '/json'),
                      onOpenMarkdown: () => _openTool(context, ref, '/vault'),
                      onOpenSnippet: () => _openTool(context, ref, '/snippets'),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSearchQuery
                                ? 'Search results'
                                : 'All developer tools',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            hasSearchQuery
                                ? '${filteredTools.length} matches found'
                                : 'Offline utilities organised in one private workspace.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                      if (!hasSearchQuery)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/settings'),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('Customise'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filteredTools.isEmpty)
                    AppEmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'No matching tools',
                      message:
                          'No tool matches “${query.trim()}”. Try JSON, API, Markdown, token, file, or format.',
                    )
                  else
                    ToolGrid(
                      tools: filteredTools,
                      favourites: favourites,
                      onOpenTool: (route) {
                        _openTool(context, ref, route);
                      },
                      onToggleFavourite: (route) {
                        ref
                            .read(dashboardPrefsProvider.notifier)
                            .toggleFavourite(route);
                      },
                    ),
                  if (!hasSearchQuery) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xxl),
                    const DashboardStatsPanel(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTool(
    BuildContext context,
    WidgetRef ref,
    String route,
  ) {
    ref.read(dashboardPrefsProvider.notifier).markRecentlyUsed(route);
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _openExternalFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();

      if (document == null || !context.mounted) return;

      if (document.isEnvLike) {
        final proceed = await _confirmSecretFile(
          context,
          document.name,
        );

        if (proceed != true || !context.mounted) return;
      }

      final route = switch (document.kind) {
        DevFileKind.markdown => '/markdown',
        DevFileKind.json => '/json',
        DevFileKind.text => '/external-text',
        DevFileKind.apiCollection => '/api',
        DevFileKind.backup => '/settings',
        DevFileKind.unsupported => null,
      };

      if (route == null) {
        _showError(context, 'This file type is not supported.');
        return;
      }

      ref.read(dashboardPrefsProvider.notifier).markRecentlyUsed(route);

      Navigator.of(
        context,
      ).pushNamed(route, arguments: document);
    } on ExternalFileException catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Could not open the selected file: $e');
    }
  }

  Future<bool?> _confirmSecretFile(
    BuildContext context,
    String name,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.key_rounded,
            color: scheme.primary,
          ),
          title: const Text('Possible secrets file'),
          content: Text(
            '“$name” may contain API keys, access tokens, passwords, or environment secrets.\n\n'
            'DevDesk will keep the file local, but avoid sharing or exporting its contents accidentally.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Open locally'),
            ),
          ],
        );
      },
    );
  }

  void _showError(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}
