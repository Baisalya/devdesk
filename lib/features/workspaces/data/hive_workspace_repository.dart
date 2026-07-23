import '../../../core/errors/failure.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';

class HiveWorkspaceRepository implements WorkspaceRepository {
  const HiveWorkspaceRepository();

  @override
  Future<List<DeveloperWorkspace>> list() async {
    try {
      final box = await LocalStorage.openBox<Map>(LocalStorage.workspacesBox);
      final workspaces = <DeveloperWorkspace>[];
      for (final entry in box.toMap().entries) {
        try {
          final workspace = DeveloperWorkspace.fromMap(entry.value);
          if (workspace.id.isEmpty || workspace.root.value.isEmpty) {
            throw const FormatException('Workspace identity is incomplete.');
          }
          workspaces.add(workspace);
        } catch (_) {
          await LocalStorage.quarantineRecord(
            boxName: LocalStorage.workspacesBox,
            recordKey: entry.key.toString(),
            value: entry.value,
          );
        }
      }
      workspaces.sort(_compareWorkspaces);
      return workspaces;
    } catch (error) {
      if (error is Failure) rethrow;
      throw StorageFailure(
        'Workspaces could not be loaded. Existing workspace files were not changed.',
        code: 'DD-WORKSPACE-LIST',
        retryable: true,
      );
    }
  }

  @override
  Future<DeveloperWorkspace?> getById(String id) async {
    if (id.trim().isEmpty) return null;
    final box = await LocalStorage.openBox<Map>(LocalStorage.workspacesBox);
    final raw = box.get(id);
    return raw == null ? null : DeveloperWorkspace.fromMap(raw);
  }

  @override
  Future<void> save(DeveloperWorkspace workspace) async {
    if (workspace.id.trim().isEmpty || workspace.name.trim().isEmpty) {
      throw ValidationFailure(
        'Workspace name and identity are required.',
        code: 'DD-WORKSPACE-INVALID',
      );
    }
    if (workspace.root.value.trim().isEmpty) {
      throw ValidationFailure(
        'Select a workspace folder.',
        code: 'DD-WORKSPACE-ROOT',
      );
    }
    try {
      final box = await LocalStorage.openBox<Map>(LocalStorage.workspacesBox);
      await box.put(workspace.id, workspace.toMap());
    } catch (error) {
      if (error is Failure) rethrow;
      throw StorageFailure(
        'Workspace metadata could not be saved. Workspace files were not changed.',
        code: 'DD-WORKSPACE-SAVE',
        retryable: true,
      );
    }
  }

  @override
  Future<void> removeFromRegistry(String id) async {
    if (id.trim().isEmpty) return;
    try {
      final box = await LocalStorage.openBox<Map>(LocalStorage.workspacesBox);
      final metadata = await LocalStorage.openBox<Map>(
        LocalStorage.workspaceMetadataBox,
      );
      final index = await LocalStorage.openBox<Map>(
        LocalStorage.workspaceIndexBox,
      );
      await box.delete(id);
      await metadata.delete(id);
      await index.delete(id);
    } catch (error) {
      throw StorageFailure(
        'Workspace could not be removed from DevDesk. Workspace files were not changed.',
        code: 'DD-WORKSPACE-REMOVE',
        retryable: true,
      );
    }
  }

  static int _compareWorkspaces(
    DeveloperWorkspace left,
    DeveloperWorkspace right,
  ) {
    if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
    return right.lastOpenedAt.compareTo(left.lastOpenedAt);
  }
}
