import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../data/hive_workspace_repository.dart';
import '../data/local_workspace_file_system.dart';
import '../domain/workspace_file_system.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return const HiveWorkspaceRepository();
});

final workspaceFileSystemProvider = Provider<WorkspaceFileSystem>((ref) {
  return const LocalWorkspaceFileSystem();
});

final workspaceRegistryProvider =
    StateNotifierProvider<WorkspaceRegistryNotifier, WorkspaceRegistryState>(
        (ref) {
  return WorkspaceRegistryNotifier(
    repository: ref.watch(workspaceRepositoryProvider),
    fileSystem: ref.watch(workspaceFileSystemProvider),
  );
});

class WorkspaceRegistryState {
  final List<DeveloperWorkspace> workspaces;
  final String? selectedId;
  final Map<String, WorkspaceHealthSummary> health;
  final bool loading;
  final String? errorMessage;

  const WorkspaceRegistryState({
    this.workspaces = const [],
    this.selectedId,
    this.health = const {},
    this.loading = false,
    this.errorMessage,
  });

  DeveloperWorkspace? get selected {
    for (final workspace in workspaces) {
      if (workspace.id == selectedId) return workspace;
    }
    return null;
  }

  WorkspaceRegistryState copyWith({
    List<DeveloperWorkspace>? workspaces,
    String? selectedId,
    Map<String, WorkspaceHealthSummary>? health,
    bool? loading,
    String? errorMessage,
    bool clearSelected = false,
    bool clearError = false,
  }) {
    return WorkspaceRegistryState(
      workspaces: workspaces ?? this.workspaces,
      selectedId: clearSelected ? null : selectedId ?? this.selectedId,
      health: health ?? this.health,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class WorkspaceRegistryNotifier extends StateNotifier<WorkspaceRegistryState> {
  final WorkspaceRepository repository;
  final WorkspaceFileSystem fileSystem;

  WorkspaceRegistryNotifier({
    required this.repository,
    required this.fileSystem,
    bool autoLoad = true,
    WorkspaceRegistryState initialState = const WorkspaceRegistryState(),
  }) : super(initialState) {
    if (autoLoad) load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final workspaces = await repository.list();
      state = state.copyWith(
        workspaces: workspaces,
        selectedId: _selectionFor(workspaces),
        loading: false,
        clearSelected: workspaces.isEmpty,
      );
    } on Failure catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage:
            'Workspaces could not be loaded. Workspace files were not changed.',
      );
    }
  }

  Future<DeveloperWorkspace?> pickAndAdd({String? name}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final root = await fileSystem.pickRoot();
      if (root == null) {
        state = state.copyWith(loading: false);
        return null;
      }
      return addRoot(root, name: name);
    } on Failure catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage:
            'The workspace folder could not be opened. No files were changed.',
      );
      return null;
    }
  }

  Future<DeveloperWorkspace> addRoot(
    WorkspaceRootRef root, {
    String? name,
  }) async {
    final duplicate = _findByRoot(root);
    if (duplicate != null) {
      await open(duplicate.id);
      state = state.copyWith(loading: false);
      return duplicate;
    }
    final now = DateTime.now().toUtc();
    final derivedName = p.basename(root.displayPath.trim());
    final workspace = DeveloperWorkspace(
      id: const Uuid().v4(),
      name: _safeName(name, derivedName),
      root: root,
      createdAt: now,
      lastOpenedAt: now,
    );
    await repository.save(workspace);
    final updated = _sort([workspace, ...state.workspaces]);
    state = state.copyWith(
      workspaces: updated,
      selectedId: workspace.id,
      loading: false,
      clearError: true,
    );
    await checkHealth(workspace.id);
    return workspace;
  }

  Future<void> open(String id) async {
    final workspace = _byId(id);
    if (workspace == null) return;
    final updatedWorkspace = workspace.copyWith(
      lastOpenedAt: DateTime.now().toUtc(),
    );
    await repository.save(updatedWorkspace);
    state = state.copyWith(
      workspaces: _sort([
        for (final item in state.workspaces)
          if (item.id == id) updatedWorkspace else item,
      ]),
      selectedId: id,
      clearError: true,
    );
    await checkHealth(id);
  }

  void select(String id) {
    if (_byId(id) != null) state = state.copyWith(selectedId: id);
  }

  Future<void> togglePinned(String id) async {
    final workspace = _byId(id);
    if (workspace == null) return;
    final updatedWorkspace = workspace.copyWith(pinned: !workspace.pinned);
    await repository.save(updatedWorkspace);
    state = state.copyWith(
      workspaces: _sort([
        for (final item in state.workspaces)
          if (item.id == id) updatedWorkspace else item,
      ]),
    );
  }

  Future<void> removeFromDevDesk(String id) async {
    await repository.removeFromRegistry(id);
    final workspaces = state.workspaces
        .where((workspace) => workspace.id != id)
        .toList(growable: false);
    final health = Map<String, WorkspaceHealthSummary>.from(state.health)
      ..remove(id);
    state = state.copyWith(
      workspaces: workspaces,
      selectedId: workspaces.isEmpty ? null : workspaces.first.id,
      clearSelected: workspaces.isEmpty,
      health: health,
      clearError: true,
    );
  }

  Future<void> checkHealth(String id) async {
    final workspace = _byId(id);
    if (workspace == null) return;
    try {
      final result = await fileSystem.inspect(workspace.root);
      state = state.copyWith(health: {...state.health, id: result});
    } on Failure catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  DeveloperWorkspace? _findByRoot(WorkspaceRootRef root) {
    final target = _rootIdentity(root);
    for (final workspace in state.workspaces) {
      if (_rootIdentity(workspace.root) == target) return workspace;
    }
    return null;
  }

  String _rootIdentity(WorkspaceRootRef root) {
    final value = root.value.trim();
    return root.platform == WorkspacePlatform.windows
        ? value.toLowerCase()
        : value;
  }

  DeveloperWorkspace? _byId(String id) {
    for (final workspace in state.workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  String? _selectionFor(List<DeveloperWorkspace> workspaces) {
    if (workspaces.isEmpty) return null;
    if (workspaces.any((item) => item.id == state.selectedId)) {
      return state.selectedId;
    }
    return workspaces.first.id;
  }

  static String _safeName(String? requested, String derived) {
    final trimmed = requested?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    if (derived.trim().isNotEmpty) return derived.trim();
    return 'Developer Workspace';
  }

  static List<DeveloperWorkspace> _sort(
    Iterable<DeveloperWorkspace> workspaces,
  ) {
    final result = workspaces.toList(growable: false);
    result.sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      return right.lastOpenedAt.compareTo(left.lastOpenedAt);
    });
    return result;
  }
}
