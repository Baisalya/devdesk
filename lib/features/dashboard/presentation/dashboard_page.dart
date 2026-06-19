import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search tools by name or description',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                );
                final openFile = OutlinedButton.icon(
                  onPressed: () => _openExternalFile(context, ref),
                  icon: const Icon(Icons.file_open),
                  label: const Text('Open File'),
                );
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 8),
                      openFile,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 8),
                    openFile,
                  ],
                );
              },
            ),
          ),
          if (query.trim().isEmpty && recentTools.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final tool = recentTools[index];
                  return ActionChip(
                    avatar: Icon(tool.icon, size: 18),
                    label: Text(tool.name),
                    onPressed: () => _openTool(context, ref, tool.route),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: recentTools.length,
              ),
            ),
          Expanded(
            child: filteredTools.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No tools found. Try a different search term.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1000
                          ? 3
                          : width >= 620
                              ? 2
                              : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: crossAxisCount == 1 ? 4.8 : 3.7,
                        ),
                        itemCount: filteredTools.length,
                        itemBuilder: (context, index) {
                          final tool = filteredTools[index];
                          final isFav = favourites.contains(tool.route);
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ToolCard(
                                  tool: tool,
                                  onTap: () =>
                                      _openTool(context, ref, tool.route),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                  ),
                                  color: isFav ? Colors.amber : null,
                                  tooltip: isFav
                                      ? 'Remove from favourites'
                                      : 'Add to favourites',
                                  onPressed: () {
                                    ref
                                        .read(dashboardPrefsProvider.notifier)
                                        .toggleFavourite(tool.route);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
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
