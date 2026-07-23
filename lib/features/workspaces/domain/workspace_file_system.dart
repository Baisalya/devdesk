import 'dart:typed_data';

import 'workspace_models.dart';

abstract interface class WorkspaceFileSystem {
  Future<WorkspaceRootRef?> pickRoot();

  Future<WorkspaceRootRef> rootFromLocalPath(String path);

  Future<WorkspaceHealthSummary> inspect(WorkspaceRootRef root);

  String normalizeRelativePath(String relativePath);

  Future<List<WorkspaceFileEntry>> list(
    WorkspaceRootRef root, {
    String relativeDirectory = '',
    int maxEntries = 10000,
  });

  Future<Uint8List> readBytes(
    WorkspaceRootRef root,
    String relativePath, {
    int maxBytes = 5 * 1024 * 1024,
  });

  Future<void> createFile(
    WorkspaceRootRef root,
    String relativePath,
    Uint8List bytes,
  );

  Future<void> writeTextAtomically(
    WorkspaceRootRef root,
    String relativePath,
    String content, {
    String? expectedFingerprint,
  });

  Stream<WorkspaceFileChange> watch(WorkspaceRootRef root);
}
