import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/security/data_redactor.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_copy_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../models/api_environment.dart';
import '../models/api_variable.dart';
import '../models/api_workspace_models.dart';
import '../provider/api_workspace_provider.dart';
import '../utils/api_workspace_executor.dart';
import '../utils/api_workspace_utils.dart';
import 'api_page.dart';

class ApiWorkspacesPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const ApiWorkspacesPage({super.key, this.initialDocument});

  @override
  ConsumerState<ApiWorkspacesPage> createState() => _ApiWorkspacesPageState();
}

class _ApiWorkspacesPageState extends ConsumerState<ApiWorkspacesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importText(
            widget.initialDocument!.content, widget.initialDocument!.name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(apiWorkspaceProvider);
    final activeWorkspace = state.activeWorkspace;
    return activeWorkspace == null
        ? _WorkspaceDashboard(
            state: state,
            onCreate: _showCreateWorkspaceDialog,
            onOpen: (workspace) {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .openWorkspace(workspace.id);
            },
            onRename: _showRenameWorkspaceDialog,
            onDuplicate: (workspace) {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .duplicateWorkspace(workspace.id);
            },
            onDelete: _confirmDeleteWorkspace,
            onArchive: (workspace) {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .archiveWorkspace(workspace.id, !workspace.archived);
            },
            onFavorite: (workspace) {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .toggleFavorite(workspace.id);
            },
            onImport: _importFromPicker,
            onQuickRequest: _openQuickRequest,
          )
        : _WorkspaceDetail(
            workspace: activeWorkspace,
            state: state,
            onBack: () =>
                ref.read(apiWorkspaceProvider.notifier).closeWorkspace(),
            onImport: _importFromPicker,
            onExportWorkspace: () => _exportWorkspace(activeWorkspace),
            onExportCollection: _exportSelectedCollection,
            onExportDocumentation: () => _exportDocumentation(activeWorkspace),
            onQuickRequest: _openQuickRequest,
            onDeleteSelectedRequest: _confirmDeleteSelectedRequest,
            onClearHistory: _confirmClearHistory,
            onRunCollection: _confirmRunCollection,
          );
  }

  Future<void> _showCreateWorkspaceDialog() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create API workspace'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Workspace name',
                    hintText: 'My Shopping App',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (created == true) {
      await ref.read(apiWorkspaceProvider.notifier).createWorkspace(
            name: name.text,
            description: description.text,
          );
    }
  }

  Future<void> _showRenameWorkspaceDialog(ApiWorkspace workspace) async {
    final name = TextEditingController(text: workspace.name);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename workspace'),
          content: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Workspace name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    if (renamed == true) {
      await ref
          .read(apiWorkspaceProvider.notifier)
          .renameWorkspace(workspace.id, name.text);
    }
  }

  Future<void> _confirmDeleteWorkspace(ApiWorkspace workspace) async {
    final confirm = await _confirm(
      title: 'Delete workspace?',
      message:
          'This deletes "${workspace.name}" workspace data and workspace history. Legacy quick-tester history is not touched.',
      action: 'Delete',
      destructive: true,
    );
    if (confirm) {
      await ref
          .read(apiWorkspaceProvider.notifier)
          .deleteWorkspace(workspace.id);
    }
  }

  Future<void> _confirmDeleteSelectedRequest() async {
    final confirm = await _confirm(
      title: 'Delete request?',
      message: 'This removes the selected saved request from the workspace.',
      action: 'Delete',
      destructive: true,
    );
    if (confirm) {
      await ref.read(apiWorkspaceProvider.notifier).deleteSelectedRequest();
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await _confirm(
      title: 'Clear workspace history?',
      message: 'This clears only the active workspace history.',
      action: 'Clear',
      destructive: true,
    );
    if (confirm) {
      await ref.read(apiWorkspaceProvider.notifier).clearHistory();
    }
  }

  Future<void> _confirmRunCollection() async {
    final state = ref.read(apiWorkspaceProvider);
    final collection = state.selectedCollection;
    if (collection == null) {
      _showSnack('Select a collection first.');
      return;
    }
    var stopOnFailure = true;
    var delayMs = 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Run collection?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DevDesk will send ${collection.requestCount} request(s) in order. Only continue if you expect these network calls.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stop on failure'),
                    value: stopOnFailure,
                    onChanged: (value) {
                      setDialogState(() => stopOnFailure = value);
                    },
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Delay between requests (ms)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      delayMs = int.tryParse(value) ?? 0;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Run'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirm == true) {
      await ref.read(apiWorkspaceProvider.notifier).runSelectedCollection(
            stopOnFailure: stopOnFailure,
            delayMs: delayMs,
          );
    }
  }

  Future<void> _importFromPicker() async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();
      if (document == null) return;
      await _importText(document.content, document.name);
    } on ExternalFileException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to import API workspace: $e');
    }
  }

  Future<void> _importText(String text, String sourceName) async {
    try {
      final document = ApiWorkspaceImportExport.decodeJsonText(text);
      final preview = ApiWorkspaceImportExport.preview(document);
      final includeSecrets = await _chooseImportMode(sourceName, preview);
      if (includeSecrets == null) return;
      final fallbackId = ApiWorkspaceIds.newId('workspace');
      if (ref.read(apiWorkspaceProvider).activeWorkspace != null &&
          document['type'] == ApiWorkspaceImportExport.collectionType) {
        final collection = ApiWorkspaceImportExport.importCollection(
          document,
          includeSecrets: includeSecrets,
          fallbackId: fallbackId,
        );
        await ref
            .read(apiWorkspaceProvider.notifier)
            .importCollection(collection);
      } else {
        final workspace = ApiWorkspaceImportExport.importWorkspace(
          document,
          includeSecrets: includeSecrets,
          fallbackId: fallbackId,
        );
        await ref
            .read(apiWorkspaceProvider.notifier)
            .importWorkspace(workspace);
      }
      _showSnack('Imported ${preview.requestsCount} request(s).');
    } on FormatException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to import API workspace: $e');
    }
  }

  Future<bool?> _chooseImportMode(
    String sourceName,
    ApiWorkspaceImportPreview preview,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import API workspace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Source: $sourceName'),
              Text('Type: ${preview.sourceType}'),
              const SizedBox(height: AppSpacing.sm),
              Text('Collections: ${preview.collectionsCount}'),
              Text('Folders: ${preview.foldersCount}'),
              Text('Requests: ${preview.requestsCount}'),
              Text('Environments: ${preview.environmentsCount}'),
              if (preview.hasSecrets)
                Text(
                  'Secrets found: ${preview.secretsCount}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (preview.hasSecrets)
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Import without secrets'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(preview.hasSecrets),
              child:
                  Text(preview.hasSecrets ? 'Import with secrets' : 'Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportWorkspace(ApiWorkspace workspace) async {
    final content = const JsonEncoder.withIndent('  ').convert(
      ApiWorkspaceImportExport.exportWorkspace(
        workspace,
        includeSecrets: false,
      ),
    );
    final path = await ExternalFileService.saveTextAs(
      suggestedName: '${_fileSafe(workspace.name)}-workspace.json',
      content: content,
      allowedExtensions: const ['json'],
      dialogTitle: 'Export API workspace',
    );
    if (path != null) _showSnack('API workspace exported.');
  }

  Future<void> _exportDocumentation(ApiWorkspace workspace) async {
    final content = ApiWorkspaceImportExport.documentationMarkdown(workspace);
    final path = await ExternalFileService.saveTextAs(
      suggestedName: '${_fileSafe(workspace.name)}-api-docs.md',
      content: content,
      allowedExtensions: const ['md'],
      dialogTitle: 'Export API documentation',
    );
    if (path != null) _showSnack('API documentation exported.');
  }

  Future<void> _exportSelectedCollection() async {
    final collection = ref.read(apiWorkspaceProvider).selectedCollection;
    if (collection == null) {
      _showSnack('Select a collection to export.');
      return;
    }
    final content = const JsonEncoder.withIndent('  ').convert(
      ApiWorkspaceImportExport.exportCollection(
        collection,
        includeSecrets: false,
      ),
    );
    final path = await ExternalFileService.saveTextAs(
      suggestedName: '${_fileSafe(collection.name)}-collection.json',
      content: content,
      allowedExtensions: const ['json'],
      dialogTitle: 'Export API collection',
    );
    if (path != null) _showSnack('API collection exported.');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  void _openQuickRequest() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ApiPage()),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _fileSafe(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class _WorkspaceDashboard extends ConsumerWidget {
  final ApiWorkspaceState state;
  final VoidCallback onCreate;
  final ValueChanged<ApiWorkspace> onOpen;
  final ValueChanged<ApiWorkspace> onRename;
  final ValueChanged<ApiWorkspace> onDuplicate;
  final ValueChanged<ApiWorkspace> onDelete;
  final ValueChanged<ApiWorkspace> onArchive;
  final ValueChanged<ApiWorkspace> onFavorite;
  final VoidCallback onImport;
  final VoidCallback onQuickRequest;

  const _WorkspaceDashboard({
    required this.state,
    required this.onCreate,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onArchive,
    required this.onFavorite,
    required this.onImport,
    required this.onQuickRequest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compactActions = MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Workspaces'),
        actions: [
          if (compactActions)
            PopupMenuButton<String>(
              tooltip: 'Workspace actions',
              onSelected: (value) {
                switch (value) {
                  case 'quick':
                    onQuickRequest();
                    return;
                  case 'import':
                    onImport();
                    return;
                  case 'create':
                    onCreate();
                    return;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'quick',
                  child: ListTile(
                    leading: Icon(Icons.bolt),
                    title: Text('Quick request'),
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload_file),
                    title: Text('Import workspace'),
                  ),
                ),
                PopupMenuItem(
                  value: 'create',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Create workspace'),
                  ),
                ),
              ],
            )
          else ...[
            TextButton.icon(
              onPressed: onQuickRequest,
              icon: const Icon(Icons.bolt),
              label: const Text('Quick Request'),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import workspace',
              onPressed: onImport,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create workspace',
              onPressed: onCreate,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Workspace'),
      ),
      body: state.loading
          ? const AppLoadingState(label: 'Loading API workspaces...')
          : state.error != null
              ? AppErrorState(message: state.error!)
              : ListView(
                  padding: AppSpacing.page(context),
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search workspaces',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: ref
                          .read(apiWorkspaceProvider.notifier)
                          .setSearchQuery,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show archived workspaces'),
                      value: state.showArchived,
                      onChanged: ref
                          .read(apiWorkspaceProvider.notifier)
                          .setShowArchived,
                    ),
                    if (state.recentWorkspaces.isNotEmpty &&
                        state.searchQuery.trim().isEmpty) ...[
                      _SectionTitle(
                        title: 'Recent workspaces',
                        subtitle: 'Jump back into the last projects you used.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _WorkspaceGrid(
                        workspaces: state.recentWorkspaces,
                        onOpen: onOpen,
                        onRename: onRename,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                        onArchive: onArchive,
                        onFavorite: onFavorite,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _SectionTitle(
                      title: 'All workspaces',
                      subtitle: '${state.visibleWorkspaces.length} visible',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.visibleWorkspaces.isEmpty)
                      AppCard(
                        child: AppEmptyState(
                          icon: Icons.api,
                          title: 'Create your first API workspace',
                          message:
                              'Organize collections, environments, auth, variables, history and runner reports locally.',
                          action: FilledButton.icon(
                            onPressed: onCreate,
                            icon: const Icon(Icons.add),
                            label: const Text('Create workspace'),
                          ),
                        ),
                      )
                    else
                      _WorkspaceGrid(
                        workspaces: state.visibleWorkspaces,
                        onOpen: onOpen,
                        onRename: onRename,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                        onArchive: onArchive,
                        onFavorite: onFavorite,
                      ),
                  ],
                ),
    );
  }
}

class _WorkspaceGrid extends StatelessWidget {
  final List<ApiWorkspace> workspaces;
  final ValueChanged<ApiWorkspace> onOpen;
  final ValueChanged<ApiWorkspace> onRename;
  final ValueChanged<ApiWorkspace> onDuplicate;
  final ValueChanged<ApiWorkspace> onDelete;
  final ValueChanged<ApiWorkspace> onArchive;
  final ValueChanged<ApiWorkspace> onFavorite;

  const _WorkspaceGrid({
    required this.workspaces,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onArchive,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: workspaces.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 220,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (context, index) {
            final workspace = workspaces[index];
            return _WorkspaceCard(
              workspace: workspace,
              onOpen: () => onOpen(workspace),
              onRename: () => onRename(workspace),
              onDuplicate: () => onDuplicate(workspace),
              onDelete: () => onDelete(workspace),
              onArchive: () => onArchive(workspace),
              onFavorite: () => onFavorite(workspace),
            );
          },
        );
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final ApiWorkspace workspace;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onFavorite;

  const _WorkspaceCard({
    required this.workspace,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onArchive,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                workspace.favorite ? Icons.star : Icons.folder_copy,
                color: workspace.favorite
                    ? AppColors.warning(context)
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'favorite':
                      onFavorite();
                      return;
                    case 'rename':
                      onRename();
                      return;
                    case 'duplicate':
                      onDuplicate();
                      return;
                    case 'archive':
                      onArchive();
                      return;
                    case 'delete':
                      onDelete();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(workspace.favorite
                        ? 'Remove favorite'
                        : 'Favorite workspace'),
                  ),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(workspace.archived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            workspace.description.isEmpty
                ? 'No description yet'
                : workspace.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppBadge(label: '${workspace.requestCount} requests'),
              AppBadge(label: '${workspace.folderCount} folders'),
              AppBadge(label: '${workspace.environmentCount} envs'),
              if (workspace.archived)
                const AppBadge(label: 'Archived', icon: Icons.archive),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Updated ${_shortDate(workspace.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDetail extends ConsumerWidget {
  final ApiWorkspace workspace;
  final ApiWorkspaceState state;
  final VoidCallback onBack;
  final VoidCallback onImport;
  final VoidCallback onExportWorkspace;
  final VoidCallback onExportCollection;
  final VoidCallback onExportDocumentation;
  final VoidCallback onQuickRequest;
  final VoidCallback onDeleteSelectedRequest;
  final VoidCallback onClearHistory;
  final VoidCallback onRunCollection;

  const _WorkspaceDetail({
    required this.workspace,
    required this.state,
    required this.onBack,
    required this.onImport,
    required this.onExportWorkspace,
    required this.onExportCollection,
    required this.onExportDocumentation,
    required this.onQuickRequest,
    required this.onDeleteSelectedRequest,
    required this.onClearHistory,
    required this.onRunCollection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    final body = isWide
        ? _DesktopWorkspaceDetail(
            state: state,
            onDeleteSelectedRequest: onDeleteSelectedRequest,
            onRunCollection: onRunCollection,
            onClearHistory: onClearHistory,
          )
        : _MobileWorkspaceDetail(
            state: state,
            onDeleteSelectedRequest: onDeleteSelectedRequest,
            onRunCollection: onRunCollection,
            onClearHistory: onClearHistory,
          );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          ref.read(apiWorkspaceProvider.notifier).sendSelectedRequest();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request autosaved locally')),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          ref.read(apiWorkspaceProvider.notifier).addRequest();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          ref
              .read(apiWorkspaceProvider.notifier)
              .setSection(ApiWorkspaceSection.collections);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to workspaces',
              onPressed: onBack,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workspace.name),
                Text(
                  workspace.activeEnvironment?.name ?? 'No environment',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: onQuickRequest,
                icon: const Icon(Icons.bolt),
                label: const Text('Quick'),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Import',
                onPressed: onImport,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      onExportWorkspace();
                      return;
                    case 'collection':
                      onExportCollection();
                      return;
                    case 'docs':
                      onExportDocumentation();
                      return;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'export', child: Text('Export workspace')),
                  PopupMenuItem(
                    value: 'collection',
                    child: Text('Export collection'),
                  ),
                  PopupMenuItem(
                    value: 'docs',
                    child: Text('Export documentation'),
                  ),
                ],
              ),
            ],
          ),
          body: body,
        ),
      ),
    );
  }
}

class _DesktopWorkspaceDetail extends ConsumerWidget {
  final ApiWorkspaceState state;
  final VoidCallback onDeleteSelectedRequest;
  final VoidCallback onRunCollection;
  final VoidCallback onClearHistory;

  const _DesktopWorkspaceDetail({
    required this.state,
    required this.onDeleteSelectedRequest,
    required this.onRunCollection,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: _WorkspaceNavigation(state: state),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: state.section == ApiWorkspaceSection.collections
              ? Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: _CollectionTree(state: state),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _RequestBuilderPanel(
                        state: state,
                        onDeleteSelectedRequest: onDeleteSelectedRequest,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 430,
                      child: _ResponseAndHistoryPanel(state: state),
                    ),
                  ],
                )
              : _WorkspaceSectionBody(
                  state: state,
                  onRunCollection: onRunCollection,
                  onClearHistory: onClearHistory,
                ),
        ),
      ],
    );
  }
}

class _MobileWorkspaceDetail extends ConsumerWidget {
  final ApiWorkspaceState state;
  final VoidCallback onDeleteSelectedRequest;
  final VoidCallback onRunCollection;
  final VoidCallback onClearHistory;

  const _MobileWorkspaceDetail({
    required this.state,
    required this.onDeleteSelectedRequest,
    required this.onRunCollection,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: ApiWorkspaceSection.values.length,
      initialIndex: state.section.index,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            onTap: (index) {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .setSection(ApiWorkspaceSection.values[index]);
            },
            tabs: const [
              Tab(text: 'Collections'),
              Tab(text: 'Environments'),
              Tab(text: 'Variables'),
              Tab(text: 'History'),
              Tab(text: 'Runner'),
              Tab(text: 'Settings'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    SizedBox(height: 360, child: _CollectionTree(state: state)),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 720,
                      child: _RequestBuilderPanel(
                        state: state,
                        onDeleteSelectedRequest: onDeleteSelectedRequest,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 620,
                      child: _ResponseAndHistoryPanel(state: state),
                    ),
                  ],
                ),
                _EnvironmentScreen(state: state),
                _VariablesScreen(state: state),
                _HistoryScreen(state: state, onClearHistory: onClearHistory),
                _RunnerScreen(state: state, onRunCollection: onRunCollection),
                _WorkspaceSettingsScreen(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceNavigation extends ConsumerWidget {
  final ApiWorkspaceState state;

  const _WorkspaceNavigation({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        _NavTile(
          section: ApiWorkspaceSection.collections,
          selected: state.section,
          icon: Icons.account_tree,
          label: 'Collections',
        ),
        _NavTile(
          section: ApiWorkspaceSection.environments,
          selected: state.section,
          icon: Icons.public,
          label: 'Environments',
        ),
        _NavTile(
          section: ApiWorkspaceSection.variables,
          selected: state.section,
          icon: Icons.data_object,
          label: 'Variables',
        ),
        _NavTile(
          section: ApiWorkspaceSection.history,
          selected: state.section,
          icon: Icons.history,
          label: 'History',
        ),
        _NavTile(
          section: ApiWorkspaceSection.runner,
          selected: state.section,
          icon: Icons.playlist_play,
          label: 'Runner',
        ),
        _NavTile(
          section: ApiWorkspaceSection.settings,
          selected: state.section,
          icon: Icons.settings,
          label: 'Settings',
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppBadge(
                  label: '${state.activeWorkspace?.requestCount ?? 0} APIs'),
              AppBadge(label: '${state.history.length} history'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavTile extends ConsumerWidget {
  final ApiWorkspaceSection section;
  final ApiWorkspaceSection selected;
  final IconData icon;
  final String label;

  const _NavTile({
    required this.section,
    required this.selected,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: selected == section,
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        ref.read(apiWorkspaceProvider.notifier).setSection(section);
      },
    );
  }
}

class _WorkspaceSectionBody extends StatelessWidget {
  final ApiWorkspaceState state;
  final VoidCallback onRunCollection;
  final VoidCallback onClearHistory;

  const _WorkspaceSectionBody({
    required this.state,
    required this.onRunCollection,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state.section) {
      ApiWorkspaceSection.environments => _EnvironmentScreen(state: state),
      ApiWorkspaceSection.variables => _VariablesScreen(state: state),
      ApiWorkspaceSection.history =>
        _HistoryScreen(state: state, onClearHistory: onClearHistory),
      ApiWorkspaceSection.runner =>
        _RunnerScreen(state: state, onRunCollection: onRunCollection),
      ApiWorkspaceSection.settings => _WorkspaceSettingsScreen(state: state),
      ApiWorkspaceSection.collections => const SizedBox.shrink(),
    };
  }
}

class _CollectionTree extends ConsumerStatefulWidget {
  final ApiWorkspaceState state;

  const _CollectionTree({required this.state});

  @override
  ConsumerState<_CollectionTree> createState() => _CollectionTreeState();
}

class _CollectionTreeState extends ConsumerState<_CollectionTree> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final workspace = widget.state.activeWorkspace;
    final collections = workspace?.collections ?? const <ApiCollection>[];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Collections',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.create_new_folder),
                      tooltip: 'New collection',
                      onPressed:
                          ref.read(apiWorkspaceProvider.notifier).addCollection,
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add),
                      tooltip: 'New request',
                      onPressed:
                          ref.read(apiWorkspaceProvider.notifier).addRequest,
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Search request tree',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: collections.isEmpty
                ? AppEmptyState(
                    icon: Icons.account_tree,
                    title: 'No collections yet',
                    message: 'Create a collection or request to begin.',
                    action: FilledButton.icon(
                      onPressed:
                          ref.read(apiWorkspaceProvider.notifier).addCollection,
                      icon: const Icon(Icons.add),
                      label: const Text('Create collection'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    children: [
                      for (final collection in collections)
                        _CollectionTile(
                          collection: collection,
                          query: _query,
                          state: widget.state,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  final ApiCollection collection;
  final String query;
  final ApiWorkspaceState state;

  const _CollectionTile({
    required this.collection,
    required this.query,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = query.trim().toLowerCase();
    bool visible(ApiRequestItem request) {
      if (normalized.isEmpty) return true;
      return request.name.toLowerCase().contains(normalized) ||
          request.url.toLowerCase().contains(normalized) ||
          request.method.toLowerCase().contains(normalized);
    }

    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(collection.name),
      subtitle: Text('${collection.requestCount} request(s)'),
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton.icon(
              onPressed: () {
                ref.read(apiWorkspaceProvider.notifier).addFolder();
              },
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Folder'),
            ),
            TextButton.icon(
              onPressed: () {
                ref.read(apiWorkspaceProvider.notifier).addRequest();
              },
              icon: const Icon(Icons.note_add),
              label: const Text('Request'),
            ),
          ],
        ),
        for (final request in collection.requests.where(visible))
          _RequestTreeTile(
            collectionId: collection.id,
            request: request,
            selected: state.selectedRequestId == request.id,
          ),
        for (final folder in collection.folders)
          ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.folder),
            title: Text(folder.name),
            trailing: IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'New request in folder',
              onPressed: () {
                ref.read(apiWorkspaceProvider.notifier).selectFolder(
                      collectionId: collection.id,
                      folderId: folder.id,
                    );
                ref
                    .read(apiWorkspaceProvider.notifier)
                    .addRequest(inFolder: true);
              },
            ),
            children: [
              for (final request in folder.requests.where(visible))
                _RequestTreeTile(
                  collectionId: collection.id,
                  folderId: folder.id,
                  request: request,
                  selected: state.selectedRequestId == request.id,
                ),
            ],
          ),
      ],
    );
  }
}

class _RequestTreeTile extends ConsumerWidget {
  final String collectionId;
  final String? folderId;
  final ApiRequestItem request;
  final bool selected;

  const _RequestTreeTile({
    required this.collectionId,
    this.folderId,
    required this.request,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: selected,
      dense: true,
      leading: _MethodBadge(method: request.method),
      title: Text(request.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(request.url, overflow: TextOverflow.ellipsis),
      onTap: () {
        ref.read(apiWorkspaceProvider.notifier).selectRequest(
              collectionId: collectionId,
              folderId: folderId,
              requestId: request.id,
            );
      },
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          ref.read(apiWorkspaceProvider.notifier).selectRequest(
                collectionId: collectionId,
                folderId: folderId,
                requestId: request.id,
              );
          switch (value) {
            case 'duplicate':
              await ref
                  .read(apiWorkspaceProvider.notifier)
                  .duplicateSelectedRequest();
              return;
            case 'move-root':
              await ref
                  .read(apiWorkspaceProvider.notifier)
                  .moveSelectedRequestToFolder(null);
              return;
            case 'delete':
              await ref
                  .read(apiWorkspaceProvider.notifier)
                  .deleteSelectedRequest();
              return;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'duplicate', child: Text('Duplicate request')),
          PopupMenuItem(value: 'move-root', child: Text('Move to collection')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _RequestBuilderPanel extends ConsumerWidget {
  final ApiWorkspaceState state;
  final VoidCallback onDeleteSelectedRequest;

  const _RequestBuilderPanel({
    required this.state,
    required this.onDeleteSelectedRequest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = state.selectedRequest;
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    if (request == null) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.request_page,
          title: 'Select or create a request',
          message: 'Saved requests can use environments, auth and variables.',
          action: FilledButton.icon(
            onPressed: notifier.addRequest,
            icon: const Icon(Icons.add),
            label: const Text('Create request'),
          ),
        ),
      );
    }
    final preview = notifier.previewSelectedRequest();
    final jsonError = request.body.type == ApiRequestBodyType.rawJson
        ? ApiJsonBodyTools.validate(request.body.raw)
        : null;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: state.sending
                      ? null
                      : () => notifier.sendSelectedRequest(),
                  icon: state.sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(state.sending ? 'Sending...' : 'Send'),
                ),
                OutlinedButton.icon(
                  onPressed: state.sending ? notifier.cancelRequest : null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: notifier.duplicateSelectedRequest,
                  icon: const Icon(Icons.copy),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: onDeleteSelectedRequest,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
                const AppBadge(label: 'Autosaved', icon: Icons.save),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextFormField(
                  key: ValueKey('request-name-${request.id}-${request.name}'),
                  initialValue: request.name,
                  decoration: const InputDecoration(
                    labelText: 'Request name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    notifier.updateSelectedRequest(
                      (request) => request.copyWith(name: value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  key: ValueKey('request-description-${request.id}'),
                  initialValue: request.description,
                  decoration: const InputDecoration(
                    labelText: 'Description / notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    notifier.updateSelectedRequest(
                      (request) => request.copyWith(description: value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _MethodUrlEditor(request: request),
                const SizedBox(height: AppSpacing.sm),
                if (preview != null)
                  _ResolvedPreview(preview: preview, error: state.error),
                if (jsonError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppErrorState(title: 'JSON body error', message: jsonError),
                ],
                const SizedBox(height: AppSpacing.md),
                _RequestOptionsEditor(request: request),
                const SizedBox(height: AppSpacing.md),
                _MapEditor(
                  title: 'Query params',
                  values: request.queryParams,
                  keyHint: 'q',
                  valueHint: 'devdesk',
                  onChanged: (values) {
                    notifier.updateSelectedRequest(
                      (request) => request.copyWith(queryParams: values),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _MapEditor(
                  title: 'Headers',
                  values: request.headers,
                  keyHint: 'Content-Type',
                  valueHint: 'application/json',
                  secretAware: true,
                  onChanged: (values) {
                    notifier.updateSelectedRequest(
                      (request) => request.copyWith(headers: values),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _AuthEditor(auth: request.auth),
                const SizedBox(height: AppSpacing.md),
                _BodyEditor(request: request),
                const SizedBox(height: AppSpacing.md),
                _VariablesEditor(
                  title: 'Request local variables',
                  variables: request.variables,
                  onChanged: (variables) {
                    notifier.updateSelectedRequest(
                      (request) => request.copyWith(variables: variables),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _AssertionsEditor(request: request),
                const SizedBox(height: AppSpacing.md),
                _ExtractionEditor(request: request),
                const SizedBox(height: AppSpacing.md),
                _DocumentationEditor(request: request),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodUrlEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _MethodUrlEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final method = DropdownButtonFormField<String>(
          key: ValueKey('workspace-method-${request.id}-${request.method}'),
          initialValue: request.method,
          decoration: const InputDecoration(
            labelText: 'Method',
            border: OutlineInputBorder(),
          ),
          items: const [
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'HEAD',
            'OPTIONS',
          ]
              .map((method) => DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            notifier.updateSelectedRequest(
              (request) => request.copyWith(method: value),
            );
          },
        );
        final url = TextFormField(
          key: ValueKey('workspace-url-${request.id}-${request.url}'),
          initialValue: request.url,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: '{{baseUrl}}/api/users/{{userId}}',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) {
            notifier.updateSelectedRequest(
              (request) => request.copyWith(url: value),
            );
          },
        );
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              method,
              const SizedBox(height: AppSpacing.sm),
              url,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 160, child: method),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: url),
          ],
        );
      },
    );
  }
}

class _ResolvedPreview extends StatelessWidget {
  final ApiPreparedRequest preview;
  final String? error;

  const _ResolvedPreview({required this.preview, required this.error});

  @override
  Widget build(BuildContext context) {
    final hasMissing = preview.hasUnresolvedVariables;
    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resolved URL preview',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppCopyButton(
                value: DataRedactor.redactUrl(preview.url),
                feedback: 'Resolved URL copied with secrets redacted',
              ),
            ],
          ),
          SelectableText(preview.url, style: AppTypography.mono(context)),
          if (hasMissing) ...[
            const SizedBox(height: AppSpacing.xs),
            AppErrorState(
              title: 'Unresolved variable warning',
              message:
                  'Missing: ${preview.unresolvedVariables.join(', ')}. DevDesk will not send until these are fixed or explicitly allowed.',
            ),
          ],
          if (error != null && !hasMissing) ...[
            const SizedBox(height: AppSpacing.xs),
            AppErrorState(title: 'Request warning', message: error!),
          ],
        ],
      ),
    );
  }
}

class _RequestOptionsEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _RequestOptionsEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    return AppCard(
      filled: false,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: TextFormField(
              key: ValueKey('timeout-${request.id}-${request.timeoutMs}'),
              initialValue: request.timeoutMs.toString(),
              decoration: const InputDecoration(
                labelText: 'Timeout (ms)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                notifier.updateSelectedRequest(
                  (request) => request.copyWith(
                    timeoutMs: int.tryParse(value) ?? request.timeoutMs,
                  ),
                );
              },
            ),
          ),
          FilterChip(
            label: const Text('Follow redirects'),
            selected: request.followRedirects,
            onSelected: (value) {
              notifier.updateSelectedRequest(
                (request) => request.copyWith(followRedirects: value),
              );
            },
          ),
          FilterChip(
            label: const Text('Important'),
            selected: request.important,
            onSelected: (value) {
              notifier.updateSelectedRequest(
                (request) => request.copyWith(important: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapEditor extends StatefulWidget {
  final String title;
  final Map<String, String> values;
  final String keyHint;
  final String valueHint;
  final bool secretAware;
  final ValueChanged<Map<String, String>> onChanged;

  const _MapEditor({
    required this.title,
    required this.values,
    required this.keyHint,
    required this.valueHint,
    required this.onChanged,
    this.secretAware = false,
  });

  @override
  State<_MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends State<_MapEditor> {
  late List<MapEntry<String, String>> _items;
  bool _showSecrets = false;

  @override
  void initState() {
    super.initState();
    _items = widget.values.entries.toList();
  }

  @override
  void didUpdateWidget(covariant _MapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _items = widget.values.entries.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.secretAware)
                IconButton(
                  icon: Icon(
                    _showSecrets ? Icons.visibility_off : Icons.visibility,
                  ),
                  tooltip: _showSecrets ? 'Hide secrets' : 'Show secrets',
                  onPressed: () => setState(() => _showSecrets = !_showSecrets),
                ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add row',
                onPressed: () {
                  setState(() => _items = [..._items, const MapEntry('', '')]);
                },
              ),
            ],
          ),
          if (_items.isEmpty)
            Text(
              'No rows yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (var index = 0; index < _items.length; index++) ...[
            _MapRow(
              key: ValueKey('${widget.title}-$index-${_items[index].key}'),
              entry: _items[index],
              keyHint: widget.keyHint,
              valueHint: widget.valueHint,
              obscureValue: widget.secretAware &&
                  !_showSecrets &&
                  _looksSensitive(_items[index].key),
              onChanged: (entry) {
                setState(() => _items[index] = entry);
                _emit();
              },
              onRemove: () {
                setState(() => _items = [..._items]..removeAt(index));
                _emit();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  void _emit() {
    widget.onChanged({
      for (final entry in _items)
        if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value,
    });
  }
}

class _MapRow extends StatelessWidget {
  final MapEntry<String, String> entry;
  final String keyHint;
  final String valueHint;
  final bool obscureValue;
  final ValueChanged<MapEntry<String, String>> onChanged;
  final VoidCallback onRemove;

  const _MapRow({
    super.key,
    required this.entry,
    required this.keyHint,
    required this.valueHint,
    required this.obscureValue,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyField = TextFormField(
          initialValue: entry.key,
          decoration: InputDecoration(
            hintText: keyHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(MapEntry(value, entry.value)),
        );
        final valueField = TextFormField(
          initialValue: entry.value,
          obscureText: obscureValue,
          decoration: InputDecoration(
            hintText: valueHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(MapEntry(entry.key, value)),
        );
        final remove = IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remove',
          onPressed: onRemove,
        );
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              keyField,
              const SizedBox(height: AppSpacing.xs),
              Row(children: [Expanded(child: valueField), remove]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: keyField),
            const SizedBox(width: AppSpacing.xs),
            Expanded(flex: 3, child: valueField),
            remove,
          ],
        );
      },
    );
  }
}

class _AuthEditor extends ConsumerStatefulWidget {
  final ApiAuthConfig auth;

  const _AuthEditor({required this.auth});

  @override
  ConsumerState<_AuthEditor> createState() => _AuthEditorState();
}

class _AuthEditorState extends ConsumerState<_AuthEditor> {
  bool _showSecrets = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    void update(ApiAuthConfig auth) {
      notifier.updateSelectedRequest((request) => request.copyWith(auth: auth));
    }

    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Auth config',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: Icon(
                    _showSecrets ? Icons.visibility_off : Icons.visibility),
                tooltip: _showSecrets ? 'Hide secrets' : 'Show secrets',
                onPressed: () => setState(() => _showSecrets = !_showSecrets),
              ),
            ],
          ),
          DropdownButtonFormField<ApiAuthType>(
            initialValue: widget.auth.type,
            decoration: const InputDecoration(
              labelText: 'Auth type',
              border: OutlineInputBorder(),
            ),
            items: ApiAuthType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_authTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              update(widget.auth.copyWith(type: value));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.auth.type == ApiAuthType.bearerToken)
            _SecretTextField(
              label: 'Bearer token',
              value: widget.auth.token,
              obscure: !_showSecrets,
              onChanged: (value) => update(widget.auth.copyWith(token: value)),
            ),
          if (widget.auth.type == ApiAuthType.basicAuth) ...[
            _PlainTextField(
              label: 'Username',
              value: widget.auth.username,
              onChanged: (value) =>
                  update(widget.auth.copyWith(username: value)),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SecretTextField(
              label: 'Password',
              value: widget.auth.password,
              obscure: !_showSecrets,
              onChanged: (value) =>
                  update(widget.auth.copyWith(password: value)),
            ),
          ],
          if (widget.auth.type == ApiAuthType.apiKeyHeader ||
              widget.auth.type == ApiAuthType.apiKeyQuery) ...[
            _PlainTextField(
              label: widget.auth.type == ApiAuthType.apiKeyHeader
                  ? 'Header name'
                  : 'Query parameter name',
              value: widget.auth.apiKeyName,
              onChanged: (value) =>
                  update(widget.auth.copyWith(apiKeyName: value)),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SecretTextField(
              label: 'API key value',
              value: widget.auth.apiKeyValue,
              obscure: !_showSecrets,
              onChanged: (value) =>
                  update(widget.auth.copyWith(apiKeyValue: value)),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Request auth overrides collection and workspace auth. No auth disables inherited auth.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BodyEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _BodyEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    void updateBody(ApiRequestBody body) {
      notifier.updateSelectedRequest((request) => request.copyWith(body: body));
    }

    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Request body',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              DropdownButton<ApiRequestBodyType>(
                value: request.body.type,
                items: ApiRequestBodyType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_bodyTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    updateBody(request.body.copyWith(type: value));
                  }
                },
              ),
            ],
          ),
          if (request.body.type == ApiRequestBodyType.none)
            const Text('No request body will be sent.')
          else if (request.body.type == ApiRequestBodyType.formUrlEncoded ||
              request.body.type == ApiRequestBodyType.multipartFormData)
            _MapEditor(
              title: request.body.type == ApiRequestBodyType.multipartFormData
                  ? 'Multipart text fields'
                  : 'Form fields',
              values: request.body.formFields,
              keyHint: 'name',
              valueHint: 'DevDesk',
              onChanged: (values) {
                updateBody(request.body.copyWith(formFields: values));
              },
            )
          else ...[
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: request.body.type == ApiRequestBodyType.rawJson
                      ? () {
                          try {
                            updateBody(
                              request.body.copyWith(
                                raw: ApiJsonBodyTools.format(request.body.raw),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invalid JSON: $e')),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Format JSON'),
                ),
                TextButton.icon(
                  onPressed: request.body.type == ApiRequestBodyType.rawJson
                      ? () {
                          try {
                            updateBody(
                              request.body.copyWith(
                                raw: ApiJsonBodyTools.minify(request.body.raw),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invalid JSON: $e')),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.compress),
                  label: const Text('Minify'),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('body-${request.id}-${request.body.raw.hashCode}'),
              initialValue: request.body.raw,
              style: AppTypography.mono(context),
              decoration: InputDecoration(
                hintText: request.body.type == ApiRequestBodyType.rawJson
                    ? '{ "key": "value" }'
                    : 'Raw text body',
                fillColor: AppColors.codeBackground(context),
                border: const OutlineInputBorder(),
              ),
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              onChanged: (value) {
                updateBody(request.body.copyWith(raw: value));
              },
            ),
          ],
          if (request.body.type == ApiRequestBodyType.multipartFormData) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Binary/file upload is not supported in this release. Multipart text fields are supported.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _VariablesEditor extends StatefulWidget {
  final String title;
  final List<ApiVariable> variables;
  final ValueChanged<List<ApiVariable>> onChanged;

  const _VariablesEditor({
    required this.title,
    required this.variables,
    required this.onChanged,
  });

  @override
  State<_VariablesEditor> createState() => _VariablesEditorState();
}

class _VariablesEditorState extends State<_VariablesEditor> {
  late List<ApiVariable> _items;
  bool _showSecrets = false;

  @override
  void initState() {
    super.initState();
    _items = widget.variables;
  }

  @override
  void didUpdateWidget(covariant _VariablesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variables != widget.variables) _items = widget.variables;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: Icon(
                    _showSecrets ? Icons.visibility_off : Icons.visibility),
                tooltip: _showSecrets ? 'Hide secrets' : 'Show secrets',
                onPressed: () => setState(() => _showSecrets = !_showSecrets),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add variable',
                onPressed: () {
                  setState(() {
                    _items = [
                      ..._items,
                      const ApiVariable(key: '', value: ''),
                    ];
                  });
                  widget.onChanged(_items);
                },
              ),
            ],
          ),
          for (var index = 0; index < _items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _VariableRow(
                variable: _items[index],
                showSecret: _showSecrets,
                onChanged: (variable) {
                  setState(() {
                    _items = [
                      for (var i = 0; i < _items.length; i++)
                        if (i == index) variable else _items[i],
                    ];
                  });
                  widget.onChanged(_items);
                },
                onRemove: () {
                  setState(() => _items = [..._items]..removeAt(index));
                  widget.onChanged(_items);
                },
              ),
            ),
          if (_items.isEmpty)
            Text(
              'No variables yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _VariableRow extends StatelessWidget {
  final ApiVariable variable;
  final bool showSecret;
  final ValueChanged<ApiVariable> onChanged;
  final VoidCallback onRemove;

  const _VariableRow({
    required this.variable,
    required this.showSecret,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: variable.key,
              decoration: const InputDecoration(
                hintText: 'baseUrl',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(variable.copyWith(key: value)),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: variable.value,
              obscureText: variable.isSecret && !showSecret,
              decoration: const InputDecoration(
                hintText: 'value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(variable.copyWith(value: value)),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilterChip(
            label: const Text('Secret'),
            selected: variable.isSecret,
            onSelected: (value) =>
                onChanged(variable.copyWith(isSecret: value)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ];
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              Row(children: fields.take(1).toList()),
              const SizedBox(height: AppSpacing.xs),
              Row(children: fields.skip(2).toList()),
            ],
          );
        }
        return Row(children: fields);
      },
    );
  }
}

class _AssertionsEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _AssertionsEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    void setAssertions(List<ApiAssertion> assertions) {
      notifier.updateSelectedRequest(
        (request) => request.copyWith(assertions: assertions),
      );
    }

    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'No-code assertions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setAssertions([
                    ...request.assertions,
                    ApiAssertion(
                      id: ApiWorkspaceIds.newId('assertion'),
                      name: 'status == 200',
                      type: ApiAssertionType.statusCodeEquals,
                      expected: '200',
                    ),
                  ]);
                },
                icon: const Icon(Icons.add),
                label: const Text('Status'),
              ),
              TextButton.icon(
                onPressed: () {
                  setAssertions([
                    ...request.assertions,
                    ApiAssertion(
                      id: ApiWorkspaceIds.newId('assertion'),
                      name: 'json path exists',
                      type: ApiAssertionType.jsonPathExists,
                      target: r'$.data',
                    ),
                  ]);
                },
                icon: const Icon(Icons.add),
                label: const Text('JSON'),
              ),
            ],
          ),
          for (var index = 0; index < request.assertions.length; index++)
            _AssertionRow(
              assertion: request.assertions[index],
              onChanged: (assertion) {
                setAssertions([
                  for (var i = 0; i < request.assertions.length; i++)
                    if (i == index) assertion else request.assertions[i],
                ]);
              },
              onRemove: () {
                setAssertions([...request.assertions]..removeAt(index));
              },
            ),
          if (request.assertions.isEmpty)
            Text(
              'Assertions are optional and safe. Runner uses them for pass/fail.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _AssertionRow extends StatelessWidget {
  final ApiAssertion assertion;
  final ValueChanged<ApiAssertion> onChanged;
  final VoidCallback onRemove;

  const _AssertionRow({
    required this.assertion,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<ApiAssertionType>(
              initialValue: assertion.type,
              decoration: const InputDecoration(
                labelText: 'Assertion',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ApiAssertionType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_assertionLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(assertion.copyWith(type: value));
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: TextFormField(
              initialValue: assertion.target,
              decoration: const InputDecoration(
                labelText: 'Target',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  onChanged(assertion.copyWith(target: value)),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextFormField(
              initialValue: assertion.expected,
              decoration: const InputDecoration(
                labelText: 'Expected',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  onChanged(assertion.copyWith(expected: value)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove assertion',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ExtractionEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _ExtractionEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    void setRules(List<ApiExtractionRule> rules) {
      notifier.updateSelectedRequest(
        (request) => request.copyWith(extractionRules: rules),
      );
    }

    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Response variable extraction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setRules([
                    ...request.extractionRules,
                    ApiExtractionRule(
                      id: ApiWorkspaceIds.newId('extract'),
                      name: 'Extract token',
                      source: ApiExtractionSource.jsonPath,
                      expression: r'$.token',
                      variableName: 'token',
                      isSecret: true,
                    ),
                  ]);
                },
                icon: const Icon(Icons.add),
                label: const Text('Extract'),
              ),
            ],
          ),
          for (var index = 0; index < request.extractionRules.length; index++)
            _ExtractionRow(
              rule: request.extractionRules[index],
              onChanged: (rule) {
                setRules([
                  for (var i = 0; i < request.extractionRules.length; i++)
                    if (i == index) rule else request.extractionRules[i],
                ]);
              },
              onRemove: () {
                setRules([...request.extractionRules]..removeAt(index));
              },
            ),
          if (request.extractionRules.isEmpty)
            Text(
              'Extract JSON paths, headers, or capped regex matches into variables. No scripts are executed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _ExtractionRow extends StatelessWidget {
  final ApiExtractionRule rule;
  final ValueChanged<ApiExtractionRule> onChanged;
  final VoidCallback onRemove;

  const _ExtractionRow({
    required this.rule,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<ApiExtractionSource>(
              initialValue: rule.source,
              decoration: const InputDecoration(
                labelText: 'Source',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ApiExtractionSource.values
                  .map(
                    (source) => DropdownMenuItem(
                      value: source,
                      child: Text(_extractionSourceLabel(source)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(rule.copyWith(source: value));
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: TextFormField(
              initialValue: rule.expression,
              decoration: const InputDecoration(
                labelText: 'Path/header/regex',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onChanged(rule.copyWith(expression: value)),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextFormField(
              initialValue: rule.variableName,
              decoration: const InputDecoration(
                labelText: 'Variable',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  onChanged(rule.copyWith(variableName: value)),
            ),
          ),
          DropdownButton<ApiVariableScope>(
            value: rule.targetScope,
            items: ApiVariableScope.values
                .map(
                  (scope) => DropdownMenuItem(
                    value: scope,
                    child: Text(scope.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(rule.copyWith(targetScope: value));
            },
          ),
          FilterChip(
            label: const Text('Secret'),
            selected: rule.isSecret,
            onSelected: (value) => onChanged(rule.copyWith(isSecret: value)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove extraction',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _DocumentationEditor extends ConsumerWidget {
  final ApiRequestItem request;

  const _DocumentationEditor({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            initialValue: request.expectedResponseNote,
            decoration: const InputDecoration(
              labelText: 'Expected response note',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) {
              notifier.updateSelectedRequest(
                (request) => request.copyWith(expectedResponseNote: value),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            initialValue: request.exampleResponse,
            style: AppTypography.mono(context),
            decoration: const InputDecoration(
              labelText: 'Example response',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            onChanged: (value) {
              notifier.updateSelectedRequest(
                (request) => request.copyWith(exampleResponse: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResponseAndHistoryPanel extends StatelessWidget {
  final ApiWorkspaceState state;

  const _ResponseAndHistoryPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Response'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ResponseViewer(
                      response: state.response, sending: state.sending),
                  _HistoryListCompact(items: state.history),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseViewer extends StatefulWidget {
  final ApiResponseRecord? response;
  final bool sending;

  const _ResponseViewer({required this.response, required this.sending});

  @override
  State<_ResponseViewer> createState() => _ResponseViewerState();
}

class _ResponseViewerState extends State<_ResponseViewer> {
  bool _raw = false;
  String _search = '';
  bool _expandedLargeBody = false;

  @override
  Widget build(BuildContext context) {
    final response = widget.response;
    if (response == null && widget.sending) {
      return const AppLoadingState(label: 'Sending request...');
    }
    if (response == null) {
      return const AppEmptyState(
        icon: Icons.receipt_long,
        title: 'Response will appear here',
        message:
            'Send a request to inspect status, headers, body and snippets.',
      );
    }
    final pretty = _pretty(response.body);
    final bodyText = _raw ? response.body : pretty;
    final isHuge = response.sizeBytes > 512 * 1024;
    final visibleBody = isHuge && !_expandedLargeBody
        ? bodyText.substring(0, bodyText.length.clamp(0, 12000))
        : bodyText;
    final matchesSearch =
        _search.trim().isEmpty || bodyText.contains(_search.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: 'Status ${response.statusCode}',
                color: _statusColor(context, response.statusCode),
                backgroundColor:
                    _statusBackground(context, response.statusCode),
              ),
              AppBadge(label: '${response.durationMs} ms', icon: Icons.timer),
              AppBadge(
                  label: _formatBytes(response.sizeBytes), icon: Icons.storage),
              AppCopyButton(
                value: DataRedactor.redactJsonText(response.body),
                feedback: 'Response copied with secrets redacted',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Raw'),
                selected: _raw,
                onSelected: (value) => setState(() => _raw = value),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Search response',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
            ],
          ),
        ),
        if (isHuge)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AppCard(
              filled: false,
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.warning(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Large response warning: ${_formatBytes(response.sizeBytes)}. Showing a collapsed preview.',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _expandedLargeBody = !_expandedLargeBody);
                    },
                    child: Text(_expandedLargeBody ? 'Collapse' : 'Expand'),
                  ),
                ],
              ),
            ),
          ),
        if (!matchesSearch)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Text('No response search matches.'),
          ),
        Expanded(
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Body'),
                    Tab(text: 'Headers'),
                    Tab(text: 'Cookies'),
                    Tab(text: 'Assertions'),
                    Tab(text: 'Extractions'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _CodePanel(text: visibleBody),
                      _HeadersPanel(headers: response.headers),
                      _HeadersPanel(headers: response.cookies),
                      _AssertionResults(results: response.assertionResults),
                      _ExtractionResults(results: response.extractionResults),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _pretty(String input) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
    } catch (_) {
      return input;
    }
  }
}

class _CodePanel extends StatelessWidget {
  final String text;

  const _CodePanel({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const AppEmptyState(
        icon: Icons.subject,
        title: 'Empty',
        message: 'No content to show.',
      );
    }
    return Container(
      color: AppColors.codeBackground(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: SelectableText(text, style: AppTypography.mono(context)),
        ),
      ),
    );
  }
}

class _HeadersPanel extends StatelessWidget {
  final Map<String, String> headers;

  const _HeadersPanel({required this.headers});

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.list_alt,
        title: 'No values',
        message: 'Values will appear here when available.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: headers.length,
      separatorBuilder: (_, __) => const Divider(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final entry = headers.entries.elementAt(index);
        return Row(
          children: [
            Expanded(
              child: SelectableText(
                '${entry.key}: ${entry.value}',
                style: AppTypography.mono(context),
              ),
            ),
            AppCopyButton(
              value: DataRedactor.redactHeaders(
                  {entry.key: entry.value})[entry.key],
              feedback: '${entry.key} copied with secrets redacted',
            ),
          ],
        );
      },
    );
  }
}

class _AssertionResults extends StatelessWidget {
  final List<ApiAssertionResult> results;

  const _AssertionResults({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.fact_check,
        title: 'No assertion results',
        message: 'Add assertions to a request and send it.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final result in results)
          ListTile(
            leading: Icon(
              result.passed ? Icons.check_circle : Icons.error,
              color: result.passed
                  ? AppColors.success(context)
                  : AppColors.destructive(context),
            ),
            title: Text(result.name),
            subtitle: Text(result.message),
          ),
      ],
    );
  }
}

class _ExtractionResults extends StatelessWidget {
  final List<ApiExtractionResult> results;

  const _ExtractionResults({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.input,
        title: 'No extraction results',
        message: 'Add extraction rules to capture variables after a response.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final result in results)
          ListTile(
            leading: Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success
                  ? AppColors.success(context)
                  : AppColors.destructive(context),
            ),
            title: Text(result.variableName),
            subtitle:
                Text(result.success ? result.displayValue : result.message),
          ),
      ],
    );
  }
}

class _EnvironmentScreen extends ConsumerWidget {
  final ApiWorkspaceState state;

  const _EnvironmentScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = state.activeWorkspace;
    if (workspace == null) return const SizedBox.shrink();
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: workspace.activeEnvironment?.id,
                decoration: const InputDecoration(
                  labelText: 'Active environment',
                  border: OutlineInputBorder(),
                ),
                items: workspace.environments
                    .map(
                      (env) => DropdownMenuItem(
                        value: env.id,
                        child: Text(env.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(apiWorkspaceProvider.notifier)
                        .selectEnvironment(value);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () {
                ref.read(apiWorkspaceProvider.notifier).updateEnvironment(
                      ApiEnvironment(
                        id: ApiWorkspaceIds.newId('env'),
                        name: 'Custom',
                        baseUrl: '',
                      ),
                    );
              },
              icon: const Icon(Icons.add),
              label: const Text('Environment'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final environment in workspace.environments) ...[
          _EnvironmentCard(environment: environment),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _EnvironmentCard extends ConsumerWidget {
  final ApiEnvironment environment;

  const _EnvironmentCard({required this.environment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(environment.name,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: environment.name,
            decoration: const InputDecoration(
              labelText: 'Environment name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              notifier.updateEnvironment(environment.copyWith(name: value));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: environment.baseUrl,
            decoration: const InputDecoration(
              labelText: 'baseUrl',
              hintText: 'https://api.example.com',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              notifier.updateEnvironment(environment.copyWith(baseUrl: value));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _VariablesEditor(
            title: 'Environment variables',
            variables: environment.variables,
            onChanged: (variables) {
              notifier.updateEnvironment(
                environment.copyWith(variables: variables),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VariablesScreen extends ConsumerWidget {
  final ApiWorkspaceState state;

  const _VariablesScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = state.activeWorkspace;
    if (workspace == null) return const SizedBox.shrink();
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        _VariablesEditor(
          title: 'Shared workspace variables',
          variables: workspace.variables,
          onChanged:
              ref.read(apiWorkspaceProvider.notifier).setWorkspaceVariables,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temporary response variables',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (state.temporaryVariables.isEmpty)
                const Text('No temporary variables extracted yet.'),
              for (final entry in state.temporaryVariables.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text(
                    _looksSensitive(entry.key) ? '••••••••' : entry.value,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryScreen extends StatefulWidget {
  final ApiWorkspaceState state;
  final VoidCallback onClearHistory;

  const _HistoryScreen({
    required this.state,
    required this.onClearHistory,
  });

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  String _query = '';
  String _method = 'ALL';

  @override
  Widget build(BuildContext context) {
    final items = widget.state.history.where((item) {
      final matchesMethod = _method == 'ALL' || item.method == _method;
      final query = _query.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          item.url.toLowerCase().contains(query) ||
          item.requestName.toLowerCase().contains(query);
      return matchesMethod && matchesQuery;
    }).toList();
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter history',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            DropdownButton<String>(
              value: _method,
              items: const ['ALL', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _method = value ?? 'ALL'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear history',
              onPressed: widget.onClearHistory,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          const AppEmptyState(
            icon: Icons.history,
            title: 'No history',
            message: 'Sent requests will appear here.',
          )
        else
          for (final item in items) _HistoryItemTile(item: item),
      ],
    );
  }
}

class _HistoryListCompact extends StatelessWidget {
  final List<ApiHistoryItem> items;

  const _HistoryListCompact({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No history',
        message: 'Workspace history is stored locally.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        for (final item in items.take(50)) _HistoryItemTile(item: item)
      ],
    );
  }
}

class _HistoryItemTile extends ConsumerWidget {
  final ApiHistoryItem item;

  const _HistoryItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _MethodBadge(method: item.method),
      title: Text(item.requestName.isEmpty ? item.url : item.requestName),
      subtitle: Text(
        '${item.url}\n${_shortDate(item.timestamp)} · ${item.statusCode ?? '-'} · ${item.durationMs ?? '-'} ms',
      ),
      isThreeLine: true,
      trailing: Wrap(
        children: [
          IconButton(
            icon: const Icon(Icons.save_as),
            tooltip: 'Save history item as request',
            onPressed: () {
              ref
                  .read(apiWorkspaceProvider.notifier)
                  .saveHistoryItemAsRequest(item);
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Re-run from history',
            onPressed: () async {
              final notifier = ref.read(apiWorkspaceProvider.notifier);
              await notifier.saveHistoryItemAsRequest(item);
              await notifier.sendSelectedRequest();
            },
          ),
        ],
      ),
    );
  }
}

class _RunnerScreen extends StatelessWidget {
  final ApiWorkspaceState state;
  final VoidCallback onRunCollection;

  const _RunnerScreen({
    required this.state,
    required this.onRunCollection,
  });

  @override
  Widget build(BuildContext context) {
    final report = state.runnerResult;
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Collection Runner',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Run the selected collection in order using the active environment. Scripts are not supported.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: state.runnerRunning ? null : onRunCollection,
                icon: state.runnerRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label:
                    Text(state.runnerRunning ? 'Running...' : 'Run collection'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (report == null)
          const AppEmptyState(
            icon: Icons.playlist_play,
            title: 'No runner report yet',
            message: 'Run a collection to see totals, failures and timing.',
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Runner result summary',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(label: 'Total ${report.totalRequests}'),
                    AppBadge(label: 'Passed ${report.passed}'),
                    AppBadge(label: 'Failed ${report.failed}'),
                    AppBadge(label: 'Skipped ${report.skipped}'),
                    AppBadge(label: 'Avg ${report.averageResponseTimeMs} ms'),
                  ],
                ),
                const Divider(),
                for (final result in report.results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      result.skipped
                          ? Icons.skip_next
                          : result.passed
                              ? Icons.check_circle
                              : Icons.error,
                      color: result.passed
                          ? AppColors.success(context)
                          : result.skipped
                              ? AppColors.warning(context)
                              : AppColors.destructive(context),
                    ),
                    title: Text(result.requestName),
                    subtitle: Text(result.message),
                    trailing: Text(result.statusCode?.toString() ?? '-'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkspaceSettingsScreen extends ConsumerWidget {
  final ApiWorkspaceState state;

  const _WorkspaceSettingsScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = state.activeWorkspace;
    if (workspace == null) return const SizedBox.shrink();
    final notifier = ref.read(apiWorkspaceProvider.notifier);
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workspace settings',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: workspace.name,
                decoration: const InputDecoration(
                  labelText: 'Workspace name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  notifier.updateWorkspace(workspace.copyWith(name: value));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: workspace.description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  notifier.updateWorkspace(
                    workspace.copyWith(description: value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save secrets in this workspace'),
                subtitle: const Text(
                  'Off by default. Authorization headers, tokens, passwords and secret variables are sanitized unless explicitly enabled.',
                ),
                value: workspace.saveSecrets,
                onChanged: (value) async {
                  if (value) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Save secrets?'),
                        content: const Text(
                          'Only enable this on a trusted device. Secrets remain local but can be exported if you include them.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Save secrets'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  notifier.updateWorkspace(
                    workspace.copyWith(saveSecrets: value),
                  );
                },
              ),
              const Divider(),
              const Text(
                'Privacy note: DevDesk stores workspace data on this device. It has no analytics, no Firebase and no backend. Network calls are sent only when you tap Send or confirm Collection Runner.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workspace documentation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: workspace.overviewMarkdown,
                decoration: const InputDecoration(
                  labelText: 'Overview markdown',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                onChanged: (value) {
                  notifier.updateWorkspace(
                    workspace.copyWith(overviewMarkdown: value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: workspace.baseUrlNotes,
                decoration: const InputDecoration(
                  labelText: 'Base URL explanation',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  notifier.updateWorkspace(
                    workspace.copyWith(baseUrlNotes: value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: workspace.authInstructions,
                decoration: const InputDecoration(
                  labelText: 'Auth instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  notifier.updateWorkspace(
                    workspace.copyWith(authInstructions: value),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlainTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _PlainTextField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _SecretTextField extends StatelessWidget {
  final String label;
  final String value;
  final bool obscure;
  final ValueChanged<String> onChanged;

  const _SecretTextField({
    required this.label,
    required this.value,
    required this.obscure,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final color = switch (method.toUpperCase()) {
      'GET' => AppColors.info(context),
      'POST' => AppColors.success(context),
      'PUT' || 'PATCH' => AppColors.warning(context),
      'DELETE' => AppColors.destructive(context),
      _ => Theme.of(context).colorScheme.primary,
    };
    return AppBadge(
      label: method.toUpperCase(),
      color: color,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

String _authTypeLabel(ApiAuthType type) {
  return switch (type) {
    ApiAuthType.inherit => 'Inherit',
    ApiAuthType.noAuth => 'No auth',
    ApiAuthType.bearerToken => 'Bearer Token',
    ApiAuthType.basicAuth => 'Basic Auth',
    ApiAuthType.apiKeyHeader => 'API Key header',
    ApiAuthType.apiKeyQuery => 'API Key query',
  };
}

String _bodyTypeLabel(ApiRequestBodyType type) {
  return switch (type) {
    ApiRequestBodyType.none => 'None',
    ApiRequestBodyType.rawJson => 'Raw JSON',
    ApiRequestBodyType.rawText => 'Raw text',
    ApiRequestBodyType.formUrlEncoded => 'Form URL encoded',
    ApiRequestBodyType.multipartFormData => 'Multipart form-data',
  };
}

String _assertionLabel(ApiAssertionType type) {
  return switch (type) {
    ApiAssertionType.statusCodeEquals => 'Status code equals',
    ApiAssertionType.responseTimeLessThan => 'Response time < ms',
    ApiAssertionType.jsonPathExists => 'JSON path exists',
    ApiAssertionType.jsonPathEquals => 'JSON path equals',
    ApiAssertionType.headerExists => 'Header exists',
    ApiAssertionType.bodyContains => 'Body contains',
  };
}

String _extractionSourceLabel(ApiExtractionSource source) {
  return switch (source) {
    ApiExtractionSource.jsonPath => 'JSON path',
    ApiExtractionSource.header => 'Header',
    ApiExtractionSource.regexBody => 'Regex body',
  };
}

bool _looksSensitive(String key) {
  final normalized = key.toLowerCase().replaceAll('-', '');
  return normalized == 'authorization' ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('apikey') ||
      normalized.contains('password');
}

String _shortDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

Color _statusColor(BuildContext context, int statusCode) {
  if (statusCode >= 200 && statusCode < 300) {
    return AppColors.success(context);
  }
  if (statusCode >= 300 && statusCode < 400) {
    return AppColors.info(context);
  }
  if (statusCode >= 400 && statusCode < 500) {
    return AppColors.warning(context);
  }
  return AppColors.destructive(context);
}

Color _statusBackground(BuildContext context, int statusCode) {
  if (statusCode >= 200 && statusCode < 300) {
    return AppColors.successContainer(context);
  }
  if (statusCode >= 300 && statusCode < 400) {
    return AppColors.infoContainer(context);
  }
  if (statusCode >= 400 && statusCode < 500) {
    return AppColors.warningContainer(context);
  }
  return Theme.of(context).colorScheme.errorContainer;
}
