import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/knowledge/domain/frontmatter_document.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_graph_builder.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_models.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_repository.dart';
import 'package:devdesk/features/knowledge/domain/markdown_link_parser.dart';
import 'package:devdesk/features/knowledge/presentation/knowledge_workspace_page.dart';
import 'package:devdesk/features/knowledge/provider/knowledge_workspace_provider.dart';
import 'package:devdesk/features/workspaces/domain/workspace_models.dart';
import 'package:devdesk/features/workspaces/domain/workspace_repository.dart';
import 'package:devdesk/features/workspaces/provider/workspace_provider.dart';

void main() {
  late _MemoryKnowledgeRepository knowledge;
  late _MemoryWorkspaceRepository workspaces;
  late DeveloperWorkspace workspace;

  setUp(() {
    final now = DateTime.utc(2026, 7, 22);
    workspace = DeveloperWorkspace(
      id: 'workspace-1',
      name: 'Knowledge Test',
      root: const WorkspaceRootRef(
        kind: WorkspaceRootKind.localPath,
        platform: WorkspacePlatform.windows,
        value: r'C:\workspace',
        displayPath: r'C:\workspace',
        capabilities: {
          WorkspaceCapability.read,
          WorkspaceCapability.write,
          WorkspaceCapability.atomicWrite,
        },
      ),
      createdAt: now,
      lastOpenedAt: now,
    );
    workspaces = _MemoryWorkspaceRepository(workspace);
    knowledge = _MemoryKnowledgeRepository();
  });

  test('matching draft is recovered and autosave persists later edits',
      () async {
    knowledge.draft = KnowledgeDraft(
      workspaceId: workspace.id,
      relativePath: 'README.md',
      content: '${knowledge.content}\nRecovered',
      baseFingerprint: knowledge.fingerprint,
      updatedAt: DateTime.utc(2026, 7, 22),
    );
    final notifier = KnowledgeWorkspaceNotifier(
      workspaceId: workspace.id,
      workspaceRepository: workspaces,
      knowledgeRepository: knowledge,
      autoLoad: false,
    );

    await notifier.load();
    expect(notifier.state.recoveredDraft, isTrue);
    expect(notifier.state.content, endsWith('Recovered'));

    notifier.updateContent('${notifier.state.content}\nAutosaved');
    await Future<void>.delayed(const Duration(milliseconds: 760));

    expect(knowledge.draft?.content, endsWith('Autosaved'));
    notifier.dispose();
  });

  test('stale draft is held as a conflict instead of overwriting disk content',
      () async {
    knowledge.draft = KnowledgeDraft(
      workspaceId: workspace.id,
      relativePath: 'README.md',
      content: '# Stale draft',
      baseFingerprint: 'old-fingerprint',
      updatedAt: DateTime.utc(2026, 7, 21),
    );
    final notifier = KnowledgeWorkspaceNotifier(
      workspaceId: workspace.id,
      workspaceRepository: workspaces,
      knowledgeRepository: knowledge,
      autoLoad: false,
    );

    await notifier.load();

    expect(notifier.state.content, knowledge.content);
    expect(notifier.state.conflictingDraft?.content, '# Stale draft');
    expect(notifier.state.dirty, isFalse);
    notifier.dispose();
  });

  test('successful save uses fingerprint and removes recovery draft', () async {
    final notifier = KnowledgeWorkspaceNotifier(
      workspaceId: workspace.id,
      workspaceRepository: workspaces,
      knowledgeRepository: knowledge,
      autoLoad: false,
    );
    await notifier.load();
    notifier.updateContent('${knowledge.content}\nSaved');

    expect(await notifier.save(), isTrue);

    expect(knowledge.content, endsWith('Saved'));
    expect(knowledge.lastExpectedFingerprint, 'fingerprint-1');
    expect(knowledge.draft, isNull);
    expect(notifier.state.dirty, isFalse);
    notifier.dispose();
  });

  for (final size in [const Size(320, 568), const Size(1200, 760)]) {
    testWidgets('knowledge workspace fits ${size.width.toInt()}px layout',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(workspaces),
            knowledgeRepositoryProvider.overrideWithValue(knowledge),
          ],
          child: MaterialApp(
            home: KnowledgeWorkspacePage(workspaceId: workspace.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace Home'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (size.width < 600) {
        expect(find.byTooltip('Browse documents'), findsOneWidget);
      } else {
        expect(find.text('Properties'), findsOneWidget);
        expect(find.text('README.md'), findsWidgets);
      }
    });
  }
}

class _MemoryWorkspaceRepository implements WorkspaceRepository {
  DeveloperWorkspace workspace;

  _MemoryWorkspaceRepository(this.workspace);

  @override
  Future<DeveloperWorkspace?> getById(String id) async {
    return id == workspace.id ? workspace : null;
  }

  @override
  Future<List<DeveloperWorkspace>> list() async => [workspace];

  @override
  Future<void> removeFromRegistry(String id) async {}

  @override
  Future<void> save(DeveloperWorkspace workspace) async {
    this.workspace = workspace;
  }
}

class _MemoryKnowledgeRepository implements KnowledgeRepository {
  String content = '''---
type: Project Documentation
title: Workspace Home
tags: [project]
---
# Workspace Home

Welcome.
''';
  String fingerprint = 'fingerprint-1';
  KnowledgeDraft? draft;
  String? lastExpectedFingerprint;

  KnowledgeDocument get document {
    final parsed = FrontmatterDocument.parse(content);
    return KnowledgeDocument(
      workspaceId: 'workspace-1',
      relativePath: 'README.md',
      title: parsed.fields['title'].toString(),
      type: parsed.fields['type'].toString(),
      description: '',
      tags: const ['project'],
      frontmatter: parsed,
      outgoingReferences: MarkdownLinkParser.parse(parsed.body),
      fingerprint: fingerprint,
      modifiedAt: DateTime.utc(2026, 7, 22),
      sizeBytes: content.length,
    );
  }

  @override
  Future<void> createDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content,
  ) async {
    this.content = content;
    fingerprint = 'fingerprint-created';
  }

  @override
  Future<void> deleteDraft(String workspaceId, String relativePath) async {
    draft = null;
  }

  @override
  Future<WorkspaceKnowledgeSnapshot> indexWorkspace(
    DeveloperWorkspace workspace, {
    int maxDocuments = 5000,
    int maxIndexedBytes = 64 * 1024 * 1024,
    int maxDocumentBytes = 2 * 1024 * 1024,
  }) async {
    return WorkspaceKnowledgeSnapshot(
      graph: KnowledgeGraphBuilder.build([document]),
      scanIssues: const [],
      scannedMarkdownFiles: 1,
      indexedBytes: content.length,
      truncated: false,
      generatedAt: DateTime.utc(2026, 7, 22),
    );
  }

  @override
  Future<String> readDocument(
    DeveloperWorkspace workspace,
    String relativePath,
  ) async {
    return content;
  }

  @override
  Future<KnowledgeDraft?> readDraft(
    String workspaceId,
    String relativePath,
  ) async {
    return draft;
  }

  @override
  Future<void> saveDocument(
    DeveloperWorkspace workspace,
    String relativePath,
    String content, {
    required String expectedFingerprint,
  }) async {
    lastExpectedFingerprint = expectedFingerprint;
    this.content = content;
    fingerprint = 'fingerprint-2';
  }

  @override
  Future<void> saveDraft(KnowledgeDraft draft) async {
    this.draft = draft;
  }
}
