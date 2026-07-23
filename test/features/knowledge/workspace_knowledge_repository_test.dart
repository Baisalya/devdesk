import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/files/external_file_service.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/knowledge/data/workspace_knowledge_repository.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_models.dart';
import 'package:devdesk/features/workspaces/data/local_workspace_file_system.dart';
import 'package:devdesk/features/workspaces/domain/workspace_models.dart';

void main() {
  late Directory storageDirectory;
  late Directory workspaceDirectory;
  const fileSystem = LocalWorkspaceFileSystem();
  const repository = WorkspaceKnowledgeRepository(fileSystem);

  setUpAll(() async {
    storageDirectory =
        await Directory.systemTemp.createTemp('devdesk_knowledge_storage_');
    LocalStorage.initializeForTest(storageDirectory.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
    workspaceDirectory =
        await Directory.systemTemp.createTemp('devdesk_knowledge_root_');
    ExternalFileService.debugAtomicReplacer = null;
  });

  tearDown(() async {
    ExternalFileService.debugAtomicReplacer = null;
    if (await workspaceDirectory.exists()) {
      await workspaceDirectory.delete(recursive: true);
    }
  });

  tearDownAll(() async {
    await LocalStorage.closeAll();
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  Future<DeveloperWorkspace> createWorkspace() async {
    final root = await fileSystem.rootFromLocalPath(workspaceDirectory.path);
    final now = DateTime.now().toUtc();
    return DeveloperWorkspace(
      id: 'workspace-knowledge',
      name: 'Knowledge',
      root: root,
      createdAt: now,
      lastOpenedAt: now,
    );
  }

  test('indexes nested Markdown and builds backlinks from workspace files',
      () async {
    final guides = Directory(
      '${workspaceDirectory.path}${Platform.pathSeparator}guides',
    );
    await guides.create();
    await File('${workspaceDirectory.path}${Platform.pathSeparator}README.md')
        .writeAsString('''---
type: Project Documentation
title: Project Home
tags: [project, docs]
---
See [Authentication](guides/auth.md).
''');
    await File('${guides.path}${Platform.pathSeparator}auth.md')
        .writeAsString('''---
type: Runbook
title: Authentication
stable_id: guide.auth
---
Back to [[Project Home]].
''');
    await File('${workspaceDirectory.path}${Platform.pathSeparator}ignored.txt')
        .writeAsString('not markdown');
    final workspace = await createWorkspace();

    final snapshot = await repository.indexWorkspace(workspace);

    expect(snapshot.graph.documents, hasLength(2));
    expect(snapshot.scannedMarkdownFiles, 2);
    expect(snapshot.truncated, isFalse);
    final home = snapshot.graph.documents
        .singleWhere((document) => document.title == 'Project Home');
    final auth = snapshot.graph.documents
        .singleWhere((document) => document.title == 'Authentication');
    expect(snapshot.graph.outgoing[home.id], contains(auth.id));
    expect(snapshot.graph.backlinks[home.id], contains(auth.id));
    expect(auth.stableId, 'guide.auth');
  });

  test('malformed and oversized documents are reported without aborting scan',
      () async {
    await File('${workspaceDirectory.path}${Platform.pathSeparator}valid.md')
        .writeAsString('---\ntype: Concept\n---\nvalid');
    await File('${workspaceDirectory.path}${Platform.pathSeparator}broken.md')
        .writeAsString('---\ntype: [broken\n---\nbody');
    await File('${workspaceDirectory.path}${Platform.pathSeparator}large.md')
        .writeAsString('x' * 200);
    final workspace = await createWorkspace();

    final snapshot = await repository.indexWorkspace(
      workspace,
      maxDocumentBytes: 100,
    );

    expect(snapshot.graph.documents, hasLength(1));
    expect(
      snapshot.scanIssues
          .where((issue) => issue.kind == KnowledgeIssueKind.malformedDocument),
      hasLength(1),
    );
    expect(
      snapshot.scanIssues
          .where((issue) => issue.kind == KnowledgeIssueKind.skippedDocument),
      hasLength(1),
    );
  });

  test('drafts survive repository recreation and delete after save', () async {
    final draft = KnowledgeDraft(
      workspaceId: 'workspace-knowledge',
      relativePath: 'README.md',
      content: '# Recovered draft',
      baseFingerprint: 'fingerprint',
      updatedAt: DateTime.utc(2026, 7, 22),
    );
    await repository.saveDraft(draft);

    final restored = await const WorkspaceKnowledgeRepository(fileSystem)
        .readDraft(draft.workspaceId, draft.relativePath);

    expect(restored?.content, draft.content);
    expect(restored?.baseFingerprint, draft.baseFingerprint);
    await repository.deleteDraft(draft.workspaceId, draft.relativePath);
    expect(
      await repository.readDraft(draft.workspaceId, draft.relativePath),
      isNull,
    );
  });

  test('save rejects an external edit before replacing the document', () async {
    final file =
        File('${workspaceDirectory.path}${Platform.pathSeparator}README.md');
    await file.writeAsString('# Original');
    final workspace = await createWorkspace();
    final snapshot = await repository.indexWorkspace(workspace);
    final original = snapshot.graph.documents.single;
    await file.writeAsString('# Changed elsewhere');
    ExternalFileService.debugAtomicReplacer = (temporary, target) async {
      await File(temporary).rename(target);
    };

    await expectLater(
      repository.saveDocument(
        workspace,
        original.relativePath,
        '# DevDesk edit',
        expectedFingerprint: original.fingerprint,
      ),
      throwsA(isA<Exception>()),
    );
    expect(await file.readAsString(), '# Changed elsewhere');
  });
}
