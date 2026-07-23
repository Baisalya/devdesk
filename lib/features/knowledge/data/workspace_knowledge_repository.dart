import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/errors/failure.dart';
import '../../../core/files/external_file.dart';
import '../../../core/storage/local_storage.dart';
import '../../workspaces/domain/workspace_file_system.dart';
import '../../workspaces/domain/workspace_models.dart';
import '../domain/frontmatter_document.dart';
import '../domain/knowledge_graph_builder.dart';
import '../domain/knowledge_models.dart';
import '../domain/knowledge_repository.dart';
import '../domain/markdown_link_parser.dart';

class WorkspaceKnowledgeRepository implements KnowledgeRepository {
  final WorkspaceFileSystem fileSystem;

  const WorkspaceKnowledgeRepository(this.fileSystem);

  @override
  Future<WorkspaceKnowledgeSnapshot> indexWorkspace(
    DeveloperWorkspace workspace, {
    int maxDocuments = 5000,
    int maxIndexedBytes = 64 * 1024 * 1024,
    int maxDocumentBytes = 2 * 1024 * 1024,
  }) async {
    if (maxDocuments < 1 || maxIndexedBytes < 1 || maxDocumentBytes < 1) {
      throw ValidationFailure(
        'Knowledge index limits must be positive.',
        code: 'DD-KNOWLEDGE-LIMIT',
      );
    }
    final queue = <String>[''];
    final documents = <KnowledgeDocument>[];
    final issues = <KnowledgeIssue>[];
    var scanned = 0;
    var indexedBytes = 0;
    var truncated = false;
    while (queue.isNotEmpty && !truncated) {
      final directory = queue.removeAt(0);
      final entries = await fileSystem.list(
        workspace.root,
        relativeDirectory: directory,
      );
      for (final entry in entries) {
        final basename = p.basename(entry.relativePath);
        if (_isExcluded(workspace.settings, basename)) continue;
        if (entry.isDirectory) {
          queue.add(entry.relativePath);
          continue;
        }
        if (entry.isLink || !_isMarkdown(entry.relativePath)) continue;
        scanned++;
        if (documents.length >= maxDocuments ||
            indexedBytes + entry.sizeBytes > maxIndexedBytes) {
          truncated = true;
          break;
        }
        if (entry.sizeBytes > maxDocumentBytes) {
          issues.add(
            KnowledgeIssue(
              kind: KnowledgeIssueKind.skippedDocument,
              documentId: '${workspace.id}:${_portable(entry.relativePath)}',
              message:
                  'Document exceeds the ${_formatBytes(maxDocumentBytes)} indexing limit.',
            ),
          );
          continue;
        }
        try {
          final bytes = await fileSystem.readBytes(
            workspace.root,
            entry.relativePath,
            maxBytes: maxDocumentBytes,
          );
          indexedBytes += bytes.length;
          final decoded = ExternalFileDetector.decodeText(bytes);
          final frontmatter = FrontmatterDocument.parse(decoded.content);
          documents.add(
            _documentFrom(
              workspace: workspace,
              entry: entry,
              source: decoded.content,
              bytes: bytes,
              frontmatter: frontmatter,
            ),
          );
        } on ParsingFailure catch (error) {
          issues.add(
            KnowledgeIssue(
              kind: KnowledgeIssueKind.malformedDocument,
              documentId: '${workspace.id}:${_portable(entry.relativePath)}',
              message: error.message,
            ),
          );
        } on Failure catch (error) {
          issues.add(
            KnowledgeIssue(
              kind: KnowledgeIssueKind.skippedDocument,
              documentId: '${workspace.id}:${_portable(entry.relativePath)}',
              message: error.message,
            ),
          );
        }
      }
    }
    return WorkspaceKnowledgeSnapshot(
      graph: KnowledgeGraphBuilder.build(documents),
      scanIssues: issues,
      scannedMarkdownFiles: scanned,
      indexedBytes: indexedBytes,
      truncated: truncated,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<String> readDocument(
    DeveloperWorkspace workspace,
    String relativePath,
  ) async {
    final bytes = await fileSystem.readBytes(workspace.root, relativePath);
    return ExternalFileDetector.decodeText(bytes).content;
  }

  @override
  Future<void> createDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content,
  ) {
    return fileSystem.createFile(
      workspace.root,
      relativePath,
      Uint8List.fromList(utf8.encode(content)),
    );
  }

  @override
  Future<void> saveDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content, {
    required String expectedFingerprint,
  }) {
    return fileSystem.writeTextAtomically(
      workspace.root,
      relativePath,
      content,
      expectedFingerprint: expectedFingerprint,
    );
  }

  @override
  Future<KnowledgeDraft?> readDraft(
    String workspaceId,
    String relativePath,
  ) async {
    final box = await LocalStorage.openBox<Map>(
      LocalStorage.workspaceMetadataBox,
    );
    final raw = box.get(_draftKey(workspaceId, relativePath));
    return raw == null ? null : KnowledgeDraft.fromMap(raw);
  }

  @override
  Future<void> saveDraft(KnowledgeDraft draft) async {
    final box = await LocalStorage.openBox<Map>(
      LocalStorage.workspaceMetadataBox,
    );
    await box.put(
      _draftKey(draft.workspaceId, draft.relativePath),
      draft.toMap(),
    );
  }

  @override
  Future<void> deleteDraft(String workspaceId, String relativePath) async {
    final box = await LocalStorage.openBox<Map>(
      LocalStorage.workspaceMetadataBox,
    );
    await box.delete(_draftKey(workspaceId, relativePath));
  }

  static KnowledgeDocument _documentFrom({
    required DeveloperWorkspace workspace,
    required WorkspaceFileEntry entry,
    required String source,
    required Uint8List bytes,
    required FrontmatterDocument frontmatter,
  }) {
    final fields = frontmatter.fields;
    final portablePath = _portable(entry.relativePath);
    final title = _stringField(fields, 'title').isNotEmpty
        ? _stringField(fields, 'title')
        : p.basenameWithoutExtension(portablePath);
    final stableId = _stringField(fields, 'stable_id');
    return KnowledgeDocument(
      workspaceId: workspace.id,
      relativePath: portablePath,
      title: title,
      type: _stringField(fields, 'type'),
      stableId: stableId.isEmpty ? null : stableId,
      description: _stringField(fields, 'description'),
      tags: _tags(fields['tags']),
      frontmatter: frontmatter,
      outgoingReferences: MarkdownLinkParser.parse(frontmatter.body),
      fingerprint: ExternalFileDetector.fingerprint(bytes),
      modifiedAt: entry.modifiedAt,
      sizeBytes: bytes.length,
    );
  }

  static bool _isExcluded(WorkspaceSettings settings, String name) {
    if (!settings.indexHiddenFiles && name.startsWith('.')) return true;
    final lower = name.toLowerCase();
    return settings.excludedNames.any((item) => item.toLowerCase() == lower);
  }

  static bool _isMarkdown(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown');
  }

  static String _portable(String value) => value.replaceAll('\\', '/');

  static String _draftKey(String workspaceId, String relativePath) {
    return 'knowledge_draft:$workspaceId:${_portable(relativePath)}';
  }

  static String _stringField(Map<String, dynamic> fields, String key) {
    final value = fields[key];
    return value == null ? '' : value.toString().trim();
  }

  static List<String> _tags(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const [];
  }

  static String _formatBytes(int value) {
    return '${(value / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
