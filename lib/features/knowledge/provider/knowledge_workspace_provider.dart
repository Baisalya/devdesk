import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/platform/window_close_guard.dart';
import '../../workspaces/domain/workspace_repository.dart';
import '../../workspaces/provider/workspace_provider.dart';
import '../data/workspace_knowledge_repository.dart';
import '../domain/frontmatter_document.dart';
import '../domain/knowledge_models.dart';
import '../domain/knowledge_repository.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return WorkspaceKnowledgeRepository(ref.watch(workspaceFileSystemProvider));
});

final knowledgeWorkspaceProvider = StateNotifierProvider.autoDispose
    .family<KnowledgeWorkspaceNotifier, KnowledgeWorkspaceState, String>(
  (ref, workspaceId) => KnowledgeWorkspaceNotifier(
    workspaceId: workspaceId,
    workspaceRepository: ref.watch(workspaceRepositoryProvider),
    knowledgeRepository: ref.watch(knowledgeRepositoryProvider),
  ),
);

class KnowledgeWorkspaceState {
  final String workspaceId;
  final WorkspaceKnowledgeSnapshot? snapshot;
  final String? selectedPath;
  final String content;
  final String baselineContent;
  final String baselineFingerprint;
  final KnowledgeDraft? conflictingDraft;
  final bool recoveredDraft;
  final bool loading;
  final bool saving;
  final String? errorMessage;

  const KnowledgeWorkspaceState({
    required this.workspaceId,
    this.snapshot,
    this.selectedPath,
    this.content = '',
    this.baselineContent = '',
    this.baselineFingerprint = '',
    this.conflictingDraft,
    this.recoveredDraft = false,
    this.loading = false,
    this.saving = false,
    this.errorMessage,
  });

  bool get dirty => selectedPath != null && content != baselineContent;

  KnowledgeDocument? get selectedDocument {
    final path = selectedPath;
    if (path == null) return null;
    for (final document in snapshot?.graph.documents ?? const []) {
      if (document.relativePath == path) return document;
    }
    return null;
  }

  KnowledgeWorkspaceState copyWith({
    WorkspaceKnowledgeSnapshot? snapshot,
    String? selectedPath,
    String? content,
    String? baselineContent,
    String? baselineFingerprint,
    KnowledgeDraft? conflictingDraft,
    bool? recoveredDraft,
    bool? loading,
    bool? saving,
    String? errorMessage,
    bool clearSelected = false,
    bool clearConflict = false,
    bool clearError = false,
  }) {
    return KnowledgeWorkspaceState(
      workspaceId: workspaceId,
      snapshot: snapshot ?? this.snapshot,
      selectedPath: clearSelected ? null : selectedPath ?? this.selectedPath,
      content: content ?? this.content,
      baselineContent: baselineContent ?? this.baselineContent,
      baselineFingerprint: baselineFingerprint ?? this.baselineFingerprint,
      conflictingDraft:
          clearConflict ? null : conflictingDraft ?? this.conflictingDraft,
      recoveredDraft: recoveredDraft ?? this.recoveredDraft,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class KnowledgeWorkspaceNotifier
    extends StateNotifier<KnowledgeWorkspaceState> {
  final String workspaceId;
  final WorkspaceRepository workspaceRepository;
  final KnowledgeRepository knowledgeRepository;
  Timer? _draftTimer;

  KnowledgeWorkspaceNotifier({
    required this.workspaceId,
    required this.workspaceRepository,
    required this.knowledgeRepository,
    bool autoLoad = true,
  }) : super(KnowledgeWorkspaceState(workspaceId: workspaceId)) {
    if (autoLoad) unawaited(load());
  }

  String get _dirtyOwner => 'knowledge:$workspaceId';

  Future<void> load({String? preferredPath}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final workspace = await workspaceRepository.getById(workspaceId);
      if (workspace == null) {
        throw ValidationFailure(
          'This workspace is no longer registered in DevDesk.',
          code: 'DD-KNOWLEDGE-WORKSPACE',
        );
      }
      final snapshot = await knowledgeRepository.indexWorkspace(workspace);
      final path =
          _availablePath(snapshot, preferredPath ?? state.selectedPath);
      state = state.copyWith(
        snapshot: snapshot,
        loading: false,
        clearSelected: path == null,
        clearError: true,
      );
      if (path != null) await selectDocument(path);
    } on Failure catch (error) {
      state = state.copyWith(loading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage:
            'Workspace knowledge could not be indexed. Source files were not changed.',
      );
    }
  }

  Future<void> selectDocument(String relativePath) async {
    _draftTimer?.cancel();
    final workspace = await workspaceRepository.getById(workspaceId);
    final document = _documentByPath(relativePath);
    if (workspace == null || document == null) return;
    try {
      final diskContent = await knowledgeRepository.readDocument(
        workspace,
        relativePath,
      );
      final draft = await knowledgeRepository.readDraft(
        workspaceId,
        relativePath,
      );
      final recoverable = draft != null &&
          draft.baseFingerprint == document.fingerprint &&
          draft.content != diskContent;
      final conflict = draft != null &&
          draft.baseFingerprint != document.fingerprint &&
          draft.content != diskContent;
      state = state.copyWith(
        selectedPath: relativePath,
        content: recoverable ? draft.content : diskContent,
        baselineContent: diskContent,
        baselineFingerprint: document.fingerprint,
        conflictingDraft: conflict ? draft : null,
        recoveredDraft: recoverable,
        clearConflict: !conflict,
        clearError: true,
      );
      unawaited(WindowCloseGuard.setDirty(_dirtyOwner, state.dirty));
    } on Failure catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  void updateContent(String content) {
    if (state.selectedPath == null || content == state.content) return;
    state = state.copyWith(content: content, recoveredDraft: false);
    unawaited(WindowCloseGuard.setDirty(_dirtyOwner, state.dirty));
    _scheduleDraft();
  }

  void applyFrontmatterFields(Map<String, Object?> changes) {
    try {
      final parsed = FrontmatterDocument.parse(state.content);
      final updated = parsed.applyFields(changes).renderWithFrontmatter();
      updateContent(updated);
    } on Failure catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<void> recoverConflictingDraft() async {
    final draft = state.conflictingDraft;
    if (draft == null) return;
    state = state.copyWith(
      content: draft.content,
      recoveredDraft: true,
      clearConflict: true,
    );
    unawaited(WindowCloseGuard.setDirty(_dirtyOwner, state.dirty));
    _scheduleDraft();
  }

  Future<void> discardDraft() async {
    final path = state.selectedPath;
    if (path == null) return;
    _draftTimer?.cancel();
    await knowledgeRepository.deleteDraft(workspaceId, path);
    state = state.copyWith(
      content: state.baselineContent,
      recoveredDraft: false,
      clearConflict: true,
      clearError: true,
    );
    unawaited(WindowCloseGuard.clear(_dirtyOwner));
  }

  Future<bool> save() async {
    final path = state.selectedPath;
    if (path == null || !state.dirty || state.saving) return !state.dirty;
    final workspace = await workspaceRepository.getById(workspaceId);
    if (workspace == null) return false;
    _draftTimer?.cancel();
    state = state.copyWith(saving: true, clearError: true);
    try {
      await knowledgeRepository.saveDocument(
        workspace,
        path,
        state.content,
        expectedFingerprint: state.baselineFingerprint,
      );
      await knowledgeRepository.deleteDraft(workspaceId, path);
      state = state.copyWith(
        baselineContent: state.content,
        saving: false,
        recoveredDraft: false,
        clearConflict: true,
      );
      unawaited(WindowCloseGuard.clear(_dirtyOwner));
      await load(preferredPath: path);
      return true;
    } on Failure catch (error) {
      state = state.copyWith(saving: false, errorMessage: error.message);
      await _persistDraft();
      return false;
    } catch (_) {
      state = state.copyWith(
        saving: false,
        errorMessage:
            'The document could not be saved safely. The recoverable draft was retained.',
      );
      await _persistDraft();
      return false;
    }
  }

  Future<void> createDocument(String relativePath) async {
    final workspace = await workspaceRepository.getById(workspaceId);
    if (workspace == null) return;
    final normalized = relativePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty ||
        (!normalized.toLowerCase().endsWith('.md') &&
            !normalized.toLowerCase().endsWith('.markdown'))) {
      state = state.copyWith(
        errorMessage: 'New knowledge documents must use .md or .markdown.',
      );
      return;
    }
    final title = normalized
        .split('/')
        .last
        .replaceFirst(RegExp(r'\.(md|markdown)$', caseSensitive: false), '');
    final content = '''---
type: Concept
title: ${_yamlString(title)}
created: ${DateTime.now().toUtc().toIso8601String()}
updated: ${DateTime.now().toUtc().toIso8601String()}
---
# $title

''';
    try {
      await knowledgeRepository.createDocument(workspace, normalized, content);
      await load(preferredPath: normalized);
    } on Failure catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    if (!state.dirty) {
      final path = state.selectedPath;
      if (path != null) {
        unawaited(knowledgeRepository.deleteDraft(workspaceId, path));
      }
      return;
    }
    _draftTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_persistDraft()),
    );
  }

  Future<void> _persistDraft() async {
    final path = state.selectedPath;
    if (path == null || !state.dirty) return;
    await knowledgeRepository.saveDraft(
      KnowledgeDraft(
        workspaceId: workspaceId,
        relativePath: path,
        content: state.content,
        baseFingerprint: state.baselineFingerprint,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  KnowledgeDocument? _documentByPath(String path) {
    for (final document in state.snapshot?.graph.documents ?? const []) {
      if (document.relativePath == path) return document;
    }
    return null;
  }

  static String? _availablePath(
    WorkspaceKnowledgeSnapshot snapshot,
    String? preferred,
  ) {
    if (preferred != null &&
        snapshot.graph.documents
            .any((document) => document.relativePath == preferred)) {
      return preferred;
    }
    return snapshot.graph.documents.isEmpty
        ? null
        : snapshot.graph.documents.first.relativePath;
  }

  static String _yamlString(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (state.dirty) unawaited(_persistDraft());
    unawaited(WindowCloseGuard.clear(_dirtyOwner));
    super.dispose();
  }
}
