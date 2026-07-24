import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../rating/provider/rating_service.dart';
import '../provider/tool_providers.dart';
import 'widgets/tool_grid.dart';

/// Dashboard page listing all available tools.
///
/// Includes:
/// - Tool search
/// - Persisted favourites
/// - Recently used tools
/// - Local developer-file opening
/// - Responsive desktop and mobile layouts
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isSearchActive = false;

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

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;

      if (!_isSearchActive) {
        _clearSearch();
      }
    });

    if (_isSearchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _openDashboardMenu(String destination) {
    switch (destination) {
      case 'favourites':
        Navigator.of(context).pushNamed('/favourites');
        break;

      case 'recent':
        Navigator.of(context).pushNamed('/recent');
        break;

      case 'settings':
        Navigator.of(context).pushNamed('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = ref.watch(filteredToolsProvider);
    final favourites = ref.watch(favouritesProvider);
    final query = ref.watch(searchQueryProvider);

    final scheme = Theme.of(context).colorScheme;
    final isCompactNavigation = AppBreakpoints.isCompact(
      MediaQuery.sizeOf(context).width,
    );

    final hasSearchQuery = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: AppSpacing.md,
        title: const _AppBarBrand(),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchActive
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
            ),
            tooltip: _isSearchActive ? 'Close search' : 'Search tools',
            onPressed: _toggleSearch,
          ),

          if (!isCompactNavigation) ...[
            _AppBarNavigationButton(
              icon: Icons.star_outline_rounded,
              label: 'Favourites',
              onPressed: () {
                Navigator.of(context).pushNamed('/favourites');
              },
            ),
            _AppBarNavigationButton(
              icon: Icons.history_rounded,
              label: 'Recent',
              onPressed: () {
                Navigator.of(context).pushNamed('/recent');
              },
            ),
            _AppBarNavigationButton(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onPressed: () {
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ] else
            PopupMenuButton<String>(
              tooltip: 'Dashboard menu',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: _openDashboardMenu,
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'favourites',
                    child: _PopupMenuItemContent(
                      icon: Icons.star_outline_rounded,
                      label: 'Favourites',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'recent',
                    child: _PopupMenuItemContent(
                      icon: Icons.history_rounded,
                      label: 'Recently used',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: _PopupMenuItemContent(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                    ),
                  ),
                ];
              },
            ),
        ],
        bottom: _isSearchActive
            ? PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search JSON, API, Markdown, tokens...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSearch,
                )
                    : null,
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        )
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = AppBreakpoints.isCompact(width);

            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: AppSpacing.page(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!hasSearchQuery) ...[
                    _DashboardHero(
                      isCompact: isCompact,
                      toolCount: filteredTools.length,
                      favouriteCount: favourites.length,
                      onOpenFile: () => _openExternalFile(context, ref),
                      onSearch: () {
                        if (!_isSearchActive) {
                          _toggleSearch();
                        } else {
                          _searchFocusNode.requestFocus();
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeader(
                      title: 'Quick start',
                      subtitle:
                      'Open a common developer task without searching.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _QuickActionsGrid(
                      onOpenFile: () => _openExternalFile(context, ref),
                      onOpenApi: () => _openTool(context, ref, '/api'),
                      onOpenJson: () => _openTool(context, ref, '/json'),
                      onOpenMarkdown: () => _openTool(context, ref, '/vault'),
                      onOpenSnippet: () => _openTool(
                        context,
                        ref,
                        '/snippets',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  AppSectionHeader(
                    title: hasSearchQuery
                        ? 'Search results'
                        : 'All developer tools',
                    subtitle: hasSearchQuery
                        ? '${filteredTools.length} result${filteredTools.length == 1 ? '' : 's'} for “${query.trim()}”'
                        : 'Offline utilities organised in one private workspace.',
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
                ],
              ),
            );
          },
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

class _AppBarBrand extends StatelessWidget {
  const _AppBarBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.developer_mode_rounded,
            color: scheme.onPrimaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DevDesk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Offline developer workspace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppBarNavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AppBarNavigationButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class _PopupMenuItemContent extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PopupMenuItemContent({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: AppSpacing.md),
        Text(label),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final bool isCompact;
  final int toolCount;
  final int favouriteCount;
  final VoidCallback onOpenFile;
  final VoidCallback onSearch;

  const _DashboardHero({
    required this.isCompact,
    required this.toolCount,
    required this.favouriteCount,
    required this.onOpenFile,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBadge(
          icon: Icons.offline_bolt_rounded,
          label: 'Private and offline-first',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Everything developers need,\nwithout leaving the app.',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Format data, test APIs, manage Markdown notes, store snippets, '
              'and open local developer files from one focused workspace.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _DashboardMetric(
              icon: Icons.widgets_outlined,
              value: '$toolCount',
              label: 'Tools',
            ),
            _DashboardMetric(
              icon: Icons.star_outline_rounded,
              value: '$favouriteCount',
              label: 'Favourites',
            ),
            const _DashboardMetric(
              icon: Icons.cloud_off_outlined,
              value: '100%',
              label: 'Offline',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open developer file'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search all tools'),
              ),
            ],
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open developer file'),
              ),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search all tools'),
              ),
            ],
          ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: isCompact
          ? content
          : Row(
        children: [
          Expanded(child: content),
          const SizedBox(width: AppSpacing.xl),
          _HeroIllustration(),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Developer tools illustration',
      image: true,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 22,
              right: 22,
              child: _FloatingToolIcon(
                icon: Icons.data_object_rounded,
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
            ),
            Positioned(
              bottom: 24,
              left: 22,
              child: _FloatingToolIcon(
                icon: Icons.api_rounded,
                backgroundColor: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
              ),
            ),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: 54,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingToolIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _FloatingToolIcon({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(
        icon,
        color: foregroundColor,
        size: 27,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DashboardMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onOpenApi;
  final VoidCallback onOpenJson;
  final VoidCallback onOpenMarkdown;
  final VoidCallback onOpenSnippet;

  const _QuickActionsGrid({
    required this.onOpenFile,
    required this.onOpenApi,
    required this.onOpenJson,
    required this.onOpenMarkdown,
    required this.onOpenSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        icon: Icons.folder_open_rounded,
        title: 'Open File',
        description: 'Open a local developer file securely.',
        onPressed: onOpenFile,
        primary: true,
      ),
      _QuickActionData(
        icon: Icons.http_rounded,
        title: 'API Request',
        description: 'Build, send and inspect HTTP requests.',
        onPressed: onOpenApi,
      ),
      _QuickActionData(
        icon: Icons.data_object_rounded,
        title: 'Format JSON',
        description: 'Validate, format and inspect JSON data.',
        onPressed: onOpenJson,
      ),
      _QuickActionData(
        icon: Icons.article_outlined,
        title: 'Markdown',
        description: 'Create or edit Markdown documents.',
        onPressed: onOpenMarkdown,
      ),
      _QuickActionData(
        icon: Icons.code_rounded,
        title: 'Code Snippet',
        description: 'Save reusable commands and code.',
        onPressed: onOpenSnippet,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columnCount = switch (width) {
          >= 1180 => 5,
          >= 760 => 3,
          >= 430 => 2,
          _ => 1,
        };

        const spacing = AppSpacing.md;

        final totalSpacing = spacing * (columnCount - 1);
        final itemWidth = (width - totalSpacing) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                height: 138,
                child: _QuickActionCard(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;
  final bool primary;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
    this.primary = false,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData action;

  const _QuickActionCard({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final iconBackground = action.primary
        ? scheme.primary
        : scheme.primaryContainer;

    final iconForeground = action.primary
        ? scheme.onPrimary
        : scheme.onPrimaryContainer;

    return Semantics(
      button: true,
      label: '${action.title}. ${action.description}',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: action.onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          action.icon,
                          color: iconForeground,
                          size: 23,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
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
}