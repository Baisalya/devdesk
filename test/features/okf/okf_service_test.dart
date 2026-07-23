import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/knowledge/domain/frontmatter_document.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_graph_builder.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_models.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_repository.dart';
import 'package:devdesk/features/knowledge/domain/markdown_link_parser.dart';
import 'package:devdesk/features/okf/data/okf_workspace_service.dart';
import 'package:devdesk/features/okf/domain/okf_models.dart';
import 'package:devdesk/features/okf/domain/okf_template_service.dart';
import 'package:devdesk/features/okf/domain/okf_validator.dart';
import 'package:devdesk/features/workspaces/domain/workspace_models.dart';

void main() {
  test('minimal OKF concept with unknown fields and type is conformant', () {
    final concept = _document(
      path: 'concept.md',
      source: '''---
type: Future Producer Type
custom_unknown:
  nested: true
---
# Concept
''',
    );
    final snapshot = _snapshot([concept]);

    final report = OkfValidator.validate(snapshot);

    expect(report.detected, isTrue);
    expect(report.conformant, isTrue);
    expect(report.totalConcepts, 1);
    expect(report.validConcepts, 1);
    expect(
      report.issues.where((issue) => issue.code == 'OKF-INDEX-MISSING'),
      hasLength(1),
    );
  });

  test('missing type is an error while broken links stay warnings', () {
    final concept = _document(
      path: 'concept.md',
      source: '''---
title: No Type
---
[Future](missing.md)
''',
    );
    final report = OkfValidator.validate(_snapshot([concept]));

    expect(report.conformant, isFalse);
    expect(
      report.issues
          .singleWhere((issue) => issue.code == 'OKF-TYPE-MISSING')
          .severity,
      OkfSeverity.error,
    );
    expect(
      report.issues
          .singleWhere((issue) => issue.code == 'OKF-LINK-BROKEN')
          .severity,
      OkfSeverity.warning,
    );
  });

  test(
      'invalid timestamps, review dates and deprecated extensions are reported',
      () {
    final concept = _document(
      path: 'concept.md',
      source: '''---
type: Concept
timestamp: not-a-date
review_after: 2026-01-01T00:00:00Z
deprecated: true
---
Body
''',
    );
    final report = OkfValidator.validate(
      _snapshot([concept]),
      now: DateTime.utc(2026, 7, 22),
    );

    expect(report.reviewDueConcepts, 1);
    expect(report.deprecatedConcepts, 1);
    expect(
        report.issues.map((issue) => issue.code),
        containsAll([
          'OKF-TIMESTAMP-INVALID',
          'OKF-REVIEW-DUE',
          'OKF-DEPRECATED-NO-REPLACEMENT',
        ]));
  });

  test('index generator preserves custom content and updates managed section',
      () async {
    final concept = _document(
      path: 'concept.md',
      source: '''---
type: Concept
title: Customer Concept
description: Customer knowledge.
---
Body
''',
    );
    final existingIndex = _document(
      path: 'index.md',
      source: '''# Custom introduction

Keep this prose.
''',
    );
    final repository = _MemoryKnowledgeRepository({
      concept.relativePath: concept.frontmatter.render(),
      existingIndex.relativePath: existingIndex.frontmatter.render(),
    });
    final service = OkfWorkspaceService(repository);
    final snapshot = _snapshot([concept, existingIndex]);

    final firstPlan = await service.planIndexes(_workspace, snapshot);

    expect(firstPlan.writes, hasLength(1));
    expect(firstPlan.writes.single.content, contains('Keep this prose.'));
    expect(firstPlan.writes.single.content,
        contains('<!-- devdesk:okf-index:start -->'));
    expect(firstPlan.writes.single.content,
        contains('[Customer Concept](concept.md)'));
  });

  test('all requested OKF templates contain type and parseable frontmatter',
      () {
    for (final template in OkfTemplateType.values) {
      final source = OkfTemplateService.create(
        template,
        title: 'Template ${template.name}',
        stableId: 'template.${template.name}',
        now: DateTime.utc(2026, 7, 22),
      );
      final parsed = FrontmatterDocument.parse(source);
      expect(parsed.fields['type'].toString(), isNotEmpty,
          reason: template.name);
      expect(parsed.fields['stable_id'], 'template.${template.name}');
    }
  });
}

final _workspace = DeveloperWorkspace(
  id: 'workspace-1',
  name: 'OKF Workspace',
  root: const WorkspaceRootRef(
    kind: WorkspaceRootKind.localPath,
    platform: WorkspacePlatform.windows,
    value: r'C:\okf',
    displayPath: r'C:\okf',
  ),
  createdAt: DateTime.utc(2026, 7, 22),
  lastOpenedAt: DateTime.utc(2026, 7, 22),
);

KnowledgeDocument _document({required String path, required String source}) {
  final parsed = FrontmatterDocument.parse(source);
  return KnowledgeDocument(
    workspaceId: 'workspace-1',
    relativePath: path,
    title: parsed.fields['title']?.toString() ?? path,
    type: parsed.fields['type']?.toString() ?? '',
    stableId: parsed.fields['stable_id']?.toString(),
    description: parsed.fields['description']?.toString() ?? '',
    tags: const [],
    frontmatter: parsed,
    outgoingReferences: MarkdownLinkParser.parse(parsed.body),
    fingerprint: 'fingerprint-$path',
    modifiedAt: DateTime.utc(2026, 7, 22),
    sizeBytes: source.length,
  );
}

WorkspaceKnowledgeSnapshot _snapshot(List<KnowledgeDocument> documents) {
  return WorkspaceKnowledgeSnapshot(
    graph: KnowledgeGraphBuilder.build(documents),
    scanIssues: const [],
    scannedMarkdownFiles: documents.length,
    indexedBytes: documents.fold(0, (sum, item) => sum + item.sizeBytes),
    truncated: false,
    generatedAt: DateTime.utc(2026, 7, 22),
  );
}

class _MemoryKnowledgeRepository implements KnowledgeRepository {
  final Map<String, String> files;

  _MemoryKnowledgeRepository(this.files);

  @override
  Future<void> createDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content,
  ) async {
    if (files.containsKey(relativePath)) throw StateError('exists');
    files[relativePath] = content;
  }

  @override
  Future<void> deleteDraft(String workspaceId, String relativePath) async {}

  @override
  Future<WorkspaceKnowledgeSnapshot> indexWorkspace(
    DeveloperWorkspace workspace, {
    int maxDocuments = 5000,
    int maxIndexedBytes = 64 * 1024 * 1024,
    int maxDocumentBytes = 2 * 1024 * 1024,
  }) async =>
      _snapshot(const []);

  @override
  Future<String> readDocument(
    DeveloperWorkspace workspace,
    String relativePath,
  ) async {
    return files[relativePath]!;
  }

  @override
  Future<KnowledgeDraft?> readDraft(
    String workspaceId,
    String relativePath,
  ) async =>
      null;

  @override
  Future<void> saveDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content, {
    required String expectedFingerprint,
  }) async {
    files[relativePath] = content;
  }

  @override
  Future<void> saveDraft(KnowledgeDraft draft) async {}
}
