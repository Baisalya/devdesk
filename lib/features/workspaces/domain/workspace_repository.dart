import 'workspace_models.dart';

abstract interface class WorkspaceRepository {
  Future<List<DeveloperWorkspace>> list();

  Future<DeveloperWorkspace?> getById(String id);

  Future<void> save(DeveloperWorkspace workspace);

  /// Removes only the DevDesk registry entry and rebuildable metadata.
  /// Workspace source files are outside this operation's authority.
  Future<void> removeFromRegistry(String id);
}
