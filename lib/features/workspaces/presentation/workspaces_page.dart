import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_input_dialog.dart';
import '../../../core/widgets/app_tool_app_bar.dart';
import '../domain/workspace_models.dart';
import '../provider/workspace_provider.dart';

class WorkspacesPage extends ConsumerStatefulWidget {
  const WorkspacesPage({super.key});

  @override
  ConsumerState<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends ConsumerState<WorkspacesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceRegistryProvider);
    final filtered = state.workspaces.where((workspace) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          workspace.name.toLowerCase().contains(query) ||
          workspace.root.displayPath.toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppToolAppBar(
        route: '/workspaces',
        actions: [
          IconButton(
            tooltip: 'Refresh workspaces',
            onPressed: state.loading
                ? null
                : () => ref.read(workspaceRegistryProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.loading ? null : _showAddWorkspace,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add workspace'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search workspaces',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.errorMessage != null) ...[
                AppErrorState(
                  title: 'Workspace action could not be completed',
                  message: state.errorMessage!,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Expanded(
                child: state.loading && state.workspaces.isEmpty
                    ? const AppLoadingState(label: 'Loading workspaces...')
                    : filtered.isEmpty
                        ? AppEmptyState(
                            icon: Icons.folder_open,
                            title: state.workspaces.isEmpty
                                ? 'No workspaces yet'
                                : 'No matching workspaces',
                            message: state.workspaces.isEmpty
                                ? 'Add a local project folder. Removing it later will never delete its files.'
                                : 'Try another workspace name or folder.',
                            action: state.workspaces.isEmpty
                                ? FilledButton.icon(
                                    onPressed: _showAddWorkspace,
                                    icon: const Icon(Icons.create_new_folder),
                                    label: const Text('Add workspace'),
                                  )
                                : null,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >=
                                  AppBreakpoints.medium) {
                                return _DesktopWorkspaceLayout(
                                  workspaces: filtered,
                                  selected: state.selected,
                                  health: state.selectedId == null
                                      ? null
                                      : state.health[state.selectedId],
                                  onSelect: (id) => ref
                                      .read(workspaceRegistryProvider.notifier)
                                      .select(id),
                                  onOpen: _openWorkspace,
                                  onPin: _togglePinned,
                                  onRemove: _confirmRemove,
                                  onHealth: _checkHealth,
                                );
                              }
                              return _WorkspaceList(
                                workspaces: filtered,
                                health: state.health,
                                onOpen: _showCompactWorkspace,
                                onPin: _togglePinned,
                                onRemove: _confirmRemove,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importWorkspace() async {
    await ref.read(workspaceRegistryProvider.notifier).pickAndAdd();
  }

  Future<void> _showAddWorkspace() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a developer workspace',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'DevDesk registers the selected folder. Your project files stay in their original location.',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop('create'),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create named workspace'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop('import'),
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: const Text('Import existing folder'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'import') {
      await _importWorkspace();
    } else if (action == 'create') {
      await _createNamedWorkspace();
    }
  }

  Future<void> _createNamedWorkspace() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const AppTextInputDialog(
        title: 'Name this workspace',
        labelText: 'Workspace name',
        hintText: 'Customer platform',
        actionLabel: 'Select folder',
        maxLength: 80,
      ),
    );
    if (name == null || !mounted) return;
    await ref.read(workspaceRegistryProvider.notifier).pickAndAdd(name: name);
  }

  Future<void> _openWorkspace(DeveloperWorkspace workspace) async {
    await ref.read(workspaceRegistryProvider.notifier).open(workspace.id);
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamed('/knowledge', arguments: workspace.id);
  }

  Future<void> _togglePinned(DeveloperWorkspace workspace) {
    return ref
        .read(workspaceRegistryProvider.notifier)
        .togglePinned(workspace.id);
  }

  Future<void> _checkHealth(DeveloperWorkspace workspace) {
    return ref
        .read(workspaceRegistryProvider.notifier)
        .checkHealth(workspace.id);
  }

  Future<void> _confirmRemove(DeveloperWorkspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove workspace from DevDesk?'),
        content: Text(
          'This removes "${workspace.name}" from the DevDesk workspace list and clears its rebuildable cache. The folder and every file inside it will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove from DevDesk'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(workspaceRegistryProvider.notifier)
        .removeFromDevDesk(workspace.id);
  }

  Future<void> _showCompactWorkspace(DeveloperWorkspace workspace) async {
    ref.read(workspaceRegistryProvider.notifier).select(workspace.id);
    await _checkHealth(workspace);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(workspaceRegistryProvider);
          final selected = state.workspaces
              .where((item) => item.id == workspace.id)
              .firstOrNull;
          if (selected == null) return const SizedBox.shrink();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: _WorkspaceDetails(
                workspace: selected,
                health: state.health[selected.id],
                onOpen: () {
                  Navigator.of(context).pop();
                  _openWorkspace(selected);
                },
                onPin: () => _togglePinned(selected),
                onRemove: () {
                  Navigator.of(context).pop();
                  _confirmRemove(selected);
                },
                onHealth: () => _checkHealth(selected),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopWorkspaceLayout extends StatelessWidget {
  final List<DeveloperWorkspace> workspaces;
  final DeveloperWorkspace? selected;
  final WorkspaceHealthSummary? health;
  final ValueChanged<String> onSelect;
  final ValueChanged<DeveloperWorkspace> onOpen;
  final ValueChanged<DeveloperWorkspace> onPin;
  final ValueChanged<DeveloperWorkspace> onRemove;
  final ValueChanged<DeveloperWorkspace> onHealth;

  const _DesktopWorkspaceLayout({
    required this.workspaces,
    required this.selected,
    required this.health,
    required this.onSelect,
    required this.onOpen,
    required this.onPin,
    required this.onRemove,
    required this.onHealth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: _WorkspaceList(
            workspaces: workspaces,
            selectedId: selected?.id,
            onOpen: (workspace) => onSelect(workspace.id),
            onPin: onPin,
            onRemove: onRemove,
          ),
        ),
        const VerticalDivider(width: AppSpacing.xl),
        Expanded(
          child: selected == null
              ? const AppEmptyState(
                  icon: Icons.folder_open,
                  title: 'Select a workspace',
                  message: 'Choose a workspace to see its health and details.',
                )
              : SingleChildScrollView(
                  child: _WorkspaceDetails(
                    workspace: selected!,
                    health: health,
                    onOpen: () => onOpen(selected!),
                    onPin: () => onPin(selected!),
                    onRemove: () => onRemove(selected!),
                    onHealth: () => onHealth(selected!),
                  ),
                ),
        ),
      ],
    );
  }
}

class _WorkspaceList extends StatelessWidget {
  final List<DeveloperWorkspace> workspaces;
  final Map<String, WorkspaceHealthSummary> health;
  final String? selectedId;
  final ValueChanged<DeveloperWorkspace> onOpen;
  final ValueChanged<DeveloperWorkspace> onPin;
  final ValueChanged<DeveloperWorkspace> onRemove;

  const _WorkspaceList({
    required this.workspaces,
    this.health = const {},
    this.selectedId,
    required this.onOpen,
    required this.onPin,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: workspaces.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final workspace = workspaces[index];
        final summary = health[workspace.id];
        return AppCard(
          onTap: () => onOpen(workspace),
          filled: selectedId != workspace.id,
          child: ListTile(
            leading: Icon(
              workspace.hasGitRepository
                  ? Icons.account_tree_outlined
                  : Icons.folder_outlined,
            ),
            title: Text(
              workspace.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              summary?.status.name ?? workspace.root.displayPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Workspace actions',
              onSelected: (value) {
                if (value == 'pin') onPin(workspace);
                if (value == 'remove') onRemove(workspace);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Text(workspace.pinned ? 'Unpin' : 'Pin'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from DevDesk'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceDetails extends StatelessWidget {
  final DeveloperWorkspace workspace;
  final WorkspaceHealthSummary? health;
  final VoidCallback onOpen;
  final VoidCallback onPin;
  final VoidCallback onRemove;
  final VoidCallback onHealth;

  const _WorkspaceDetails({
    required this.workspace,
    required this.health,
    required this.onOpen,
    required this.onPin,
    required this.onRemove,
    required this.onHealth,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(workspace.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          workspace.root.displayPath,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open workspace'),
            ),
            OutlinedButton.icon(
              onPressed: onHealth,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Check health'),
            ),
            OutlinedButton.icon(
              onPressed: onPin,
              icon: Icon(
                  workspace.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              label: Text(workspace.pinned ? 'Unpin' : 'Pin'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Workspace health',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (health == null)
                const Text('Run a health check to verify folder access.')
              else ...[
                _DetailRow(label: 'Status', value: health!.status.name),
                _DetailRow(
                    label: 'Readable', value: health!.canRead ? 'Yes' : 'No'),
                _DetailRow(
                    label: 'Writable', value: health!.canWrite ? 'Yes' : 'No'),
                for (final notice in health!.notices)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(notice),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Safety boundary',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Removing this workspace from DevDesk only clears its registry entry and rebuildable cache. DevDesk does not delete the folder or its files.',
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Remove from DevDesk'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
