import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tool_list.dart';
import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_tool_chip.dart';
import '../../../core/widgets/tool_card.dart';
import '../provider/tool_providers.dart';

/// Dashboard page listing all available tools. Includes search, persisted
/// favourites and persisted recently used tools.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTools = ref.watch(filteredToolsProvider);
    final favourites = ref.watch(favouritesProvider);
    final recentTools = ref.watch(recentToolsProvider);
    final query = ref.watch(searchQueryProvider);
    final favouriteTools =
        tools.where((tool) => favourites.contains(tool.route)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DevDesk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = AppBreakpoints.isCompact(width);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: AppSpacing.page(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(
                    isCompact: isCompact,
                    onOpenFile: () => _openExternalFile(context, ref),
                    onOpenApi: () => _openTool(context, ref, '/api'),
                    onOpenJson: () => _openTool(context, ref, '/json'),
                    onOpenMarkdown: () => _openTool(context, ref, '/markdown'),
                    onOpenSnippet: () => _openTool(context, ref, '/snippets'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SearchBar(
                    query: query,
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                  ),
                  if (query.trim().isEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _FavouriteSection(
                      tools: favouriteTools,
                      onOpenTool: (route) => _openTool(context, ref, route),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _RecentSection(
                      tools: recentTools,
                      onOpenTool: (route) => _openTool(context, ref, route),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppSectionHeader(
                    title: query.trim().isEmpty
                        ? 'All developer tools'
                        : 'Search results',
                    subtitle: query.trim().isEmpty
                        ? 'Offline utilities for day-to-day development work.'
                        : '${filteredTools.length} tool(s) match "$query"',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filteredTools.isEmpty)
                    const AppEmptyState(
                      icon: Icons.search_off,
                      title: 'No tools found',
                      message: 'Try another name, format, token, API, or file.',
                    )
                  else
                    _ToolGrid(
                      tools: filteredTools,
                      favourites: favourites,
                      onOpenTool: (route) => _openTool(context, ref, route),
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

  void _openTool(BuildContext context, WidgetRef ref, String route) {
    ref.read(dashboardPrefsProvider.notifier).markRecentlyUsed(route);
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _openExternalFile(BuildContext context, WidgetRef ref) async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();
      if (document == null || !context.mounted) return;
      if (document.isEnvLike) {
        final proceed = await _confirmSecretFile(context, document.name);
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
        _showError(context, 'Unsupported file type.');
        return;
      }
      ref.read(dashboardPrefsProvider.notifier).markRecentlyUsed(route);
      Navigator.of(context).pushNamed(route, arguments: document);
    } on ExternalFileException catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Could not open file: $e');
    }
  }

  Future<bool?> _confirmSecretFile(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Open possible secrets file?'),
          content: Text(
            '"$name" may contain tokens, API keys, or environment secrets. DevDesk will keep it local, but be careful when copying or exporting it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open locally'),
            ),
          ],
        );
      },
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenApi;
  final VoidCallback onOpenJson;
  final VoidCallback onOpenMarkdown;
  final VoidCallback onOpenSnippet;

  const _DashboardHeader({
    required this.isCompact,
    required this.onOpenFile,
    required this.onOpenApi,
    required this.onOpenJson,
    required this.onOpenMarkdown,
    required this.onOpenSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DevKit Offline',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Offline developer toolbox',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tools for JSON, APIs, Markdown, tokens, snippets and more.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _QuickAction(
          icon: Icons.file_open,
          label: 'Open File',
          onPressed: onOpenFile,
          primary: true,
        ),
        _QuickAction(
          icon: Icons.api,
          label: 'API Request',
          onPressed: onOpenApi,
        ),
        _QuickAction(
          icon: Icons.data_object,
          label: 'Format JSON',
          onPressed: onOpenJson,
        ),
        _QuickAction(
          icon: Icons.edit_document,
          label: 'New Markdown',
          onPressed: onOpenMarkdown,
        ),
        _QuickAction(
          icon: Icons.note_add,
          label: 'New Snippet',
          onPressed: onOpenSnippet,
        ),
      ],
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: AppSpacing.lg),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: actions,
                ),
              ],
            ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('dashboard-search'),
      controller: TextEditingController(text: query)
        ..selection = TextSelection.collapsed(offset: query.length),
      decoration: const InputDecoration(
        hintText: 'Search tools by name or description',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: onChanged,
    );
  }
}

class _FavouriteSection extends StatelessWidget {
  final List<DevTool> tools;
  final ValueChanged<String> onOpenTool;

  const _FavouriteSection({
    required this.tools,
    required this.onOpenTool,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Favourites',
            subtitle: 'Pin tools you use constantly.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (tools.isEmpty)
            Text(
              'Tap the star on any tool to keep it here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tool in tools)
                  AppToolChip(
                    icon: tool.icon,
                    label: tool.name,
                    onPressed: () => onOpenTool(tool.route),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  final List<DevTool> tools;
  final ValueChanged<String> onOpenTool;

  const _RecentSection({
    required this.tools,
    required this.onOpenTool,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Recent',
            subtitle: 'Quickly jump back into your last tools.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (tools.isEmpty)
            Text(
              'Your recently opened tools and files will appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tool in tools)
                  AppToolChip(
                    icon: tool.icon,
                    label: tool.name,
                    onPressed: () => onOpenTool(tool.route),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  final List<DevTool> tools;
  final Set<String> favourites;
  final ValueChanged<String> onOpenTool;
  final ValueChanged<String> onToggleFavourite;

  const _ToolGrid({
    required this.tools,
    required this.favourites,
    required this.onOpenTool,
    required this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1600
            ? 4
            : width >= 900
                ? 3
                : width >= AppBreakpoints.compact
                    ? 2
                    : 1;
        final childAspectRatio = switch (crossAxisCount) {
          1 => 3.2,
          2 => 2.55,
          3 => 2.45,
          _ => 2.25,
        };
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            final isFav = favourites.contains(tool.route);
            return ToolCard(
              tool: tool,
              favourite: isFav,
              onTap: () => onOpenTool(tool.route),
              onFavouritePressed: () => onToggleFavourite(tool.route),
              dense: crossAxisCount > 2,
            );
          },
        );
      },
    );
  }
}
