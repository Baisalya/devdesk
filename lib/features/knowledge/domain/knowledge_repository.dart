import '../../workspaces/domain/workspace_models.dart';
import 'knowledge_models.dart';

abstract interface class KnowledgeRepository {
  Future<WorkspaceKnowledgeSnapshot> indexWorkspace(
    DeveloperWorkspace workspace, {
    int maxDocuments = 5000,
    int maxIndexedBytes = 64 * 1024 * 1024,
    int maxDocumentBytes = 2 * 1024 * 1024,
  });

  Future<String> readDocument(
    DeveloperWorkspace workspace,
    String relativePath,
  );

  Future<void> createDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content,
  );

  Future<void> saveDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content, {
    required String expectedFingerprint,
  });

  Future<KnowledgeDraft?> readDraft(
    String workspaceId,
    String relativePath,
  );

  Future<void> saveDraft(KnowledgeDraft draft);

  Future<void> deleteDraft(String workspaceId, String relativePath);
}
