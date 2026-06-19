import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/api_environment.dart';
import '../models/api_variable.dart';
import '../models/api_workspace_models.dart';
import '../utils/api_workspace_executor.dart';
import '../utils/api_workspace_utils.dart';
import 'api_workspace_storage.dart';

enum ApiWorkspaceSection {
  collections,
  environments,
  variables,
  history,
  runner,
  settings,
}

class ApiWorkspaceState {
  final bool loading;
  final bool sending;
  final bool runnerRunning;
  final String? error;
  final List<ApiWorkspace> workspaces;
  final String searchQuery;
  final bool showArchived;
  final String? activeWorkspaceId;
  final String? selectedCollectionId;
  final String? selectedFolderId;
  final String? selectedRequestId;
  final ApiWorkspaceSection section;
  final ApiResponseRecord? response;
  final List<ApiHistoryItem> history;
  final List<ApiRunnerResult> reports;
  final ApiRunnerResult? runnerResult;
  final Map<String, String> temporaryVariables;

  const ApiWorkspaceState({
    this.loading = false,
    this.sending = false,
    this.runnerRunning = false,
    this.error,
    this.workspaces = const [],
    this.searchQuery = '',
    this.showArchived = false,
    this.activeWorkspaceId,
    this.selectedCollectionId,
    this.selectedFolderId,
    this.selectedRequestId,
    this.section = ApiWorkspaceSection.collections,
    this.response,
    this.history = const [],
    this.reports = const [],
    this.runnerResult,
    this.temporaryVariables = const {},
  });

  ApiWorkspace? get activeWorkspace {
    for (final workspace in workspaces) {
      if (workspace.id == activeWorkspaceId) return workspace;
    }
    return null;
  }

  ApiCollection? get selectedCollection {
    final workspace = activeWorkspace;
    if (workspace == null) return null;
    for (final collection in workspace.collections) {
      if (collection.id == selectedCollectionId) return collection;
    }
    return workspace.collections.isEmpty ? null : workspace.collections.first;
  }

  ApiFolder? get selectedFolder {
    final collection = selectedCollection;
    if (collection == null || selectedFolderId == null) return null;
    for (final folder in collection.folders) {
      if (folder.id == selectedFolderId) return folder;
    }
    return null;
  }

  ApiRequestItem? get selectedRequest {
    final collection = selectedCollection;
    if (collection == null || selectedRequestId == null) return null;
    for (final request in collection.requests) {
      if (request.id == selectedRequestId) return request;
    }
    for (final folder in collection.folders) {
      for (final request in folder.requests) {
        if (request.id == selectedRequestId) return request;
      }
    }
    return null;
  }

  List<ApiWorkspace> get visibleWorkspaces {
    final query = searchQuery.trim().toLowerCase();
    return workspaces.where((workspace) {
      if (!showArchived && workspace.archived) return false;
      if (query.isEmpty) return true;
      return workspace.name.toLowerCase().contains(query) ||
          workspace.description.toLowerCase().contains(query);
    }).toList();
  }

  List<ApiWorkspace> get recentWorkspaces {
    final recent = workspaces.where((workspace) => !workspace.archived).toList()
      ..sort((a, b) {
        final aDate = a.lastUsedAt ?? a.updatedAt;
        final bDate = b.lastUsedAt ?? b.updatedAt;
        return bDate.compareTo(aDate);
      });
    return recent.take(4).toList();
  }

  ApiWorkspaceState copyWith({
    bool? loading,
    bool? sending,
    bool? runnerRunning,
    Object? error = _sentinel,
    List<ApiWorkspace>? workspaces,
    String? searchQuery,
    bool? showArchived,
    Object? activeWorkspaceId = _sentinel,
    Object? selectedCollectionId = _sentinel,
    Object? selectedFolderId = _sentinel,
    Object? selectedRequestId = _sentinel,
    ApiWorkspaceSection? section,
    Object? response = _sentinel,
    List<ApiHistoryItem>? history,
    List<ApiRunnerResult>? reports,
    Object? runnerResult = _sentinel,
    Map<String, String>? temporaryVariables,
  }) {
    return ApiWorkspaceState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      runnerRunning: runnerRunning ?? this.runnerRunning,
      error: identical(error, _sentinel) ? this.error : error as String?,
      workspaces: workspaces ?? this.workspaces,
      searchQuery: searchQuery ?? this.searchQuery,
      showArchived: showArchived ?? this.showArchived,
      activeWorkspaceId: identical(activeWorkspaceId, _sentinel)
          ? this.activeWorkspaceId
          : activeWorkspaceId as String?,
      selectedCollectionId: identical(selectedCollectionId, _sentinel)
          ? this.selectedCollectionId
          : selectedCollectionId as String?,
      selectedFolderId: identical(selectedFolderId, _sentinel)
          ? this.selectedFolderId
          : selectedFolderId as String?,
      selectedRequestId: identical(selectedRequestId, _sentinel)
          ? this.selectedRequestId
          : selectedRequestId as String?,
      section: section ?? this.section,
      response: identical(response, _sentinel)
          ? this.response
          : response as ApiResponseRecord?,
      history: history ?? this.history,
      reports: reports ?? this.reports,
      runnerResult: identical(runnerResult, _sentinel)
          ? this.runnerResult
          : runnerResult as ApiRunnerResult?,
      temporaryVariables: temporaryVariables ?? this.temporaryVariables,
    );
  }
}

const Object _sentinel = Object();

final apiWorkspaceProvider =
    StateNotifierProvider<ApiWorkspaceNotifier, ApiWorkspaceState>((ref) {
  return ApiWorkspaceNotifier();
});

class ApiWorkspaceNotifier extends StateNotifier<ApiWorkspaceState> {
  ApiWorkspaceNotifier({
    bool autoLoad = true,
    ApiWorkspaceState? initialState,
  }) : super(initialState ?? const ApiWorkspaceState()) {
    if (autoLoad) load();
  }

  http.Client? _activeClient;

  void replaceStateForTesting(ApiWorkspaceState nextState) {
    state = nextState;
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final workspaces = await ApiWorkspaceStorage.loadWorkspaces();
      state = state.copyWith(loading: false, workspaces: workspaces);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setShowArchived(bool value) {
    state = state.copyWith(showArchived: value);
  }

  void setSection(ApiWorkspaceSection section) {
    state = state.copyWith(section: section);
  }

  Future<ApiWorkspace> createWorkspace({
    required String name,
    String description = '',
  }) async {
    final id = ApiWorkspaceIds.newId('workspace');
    final workspace = ApiWorkspace(
      id: id,
      name: name.trim().isEmpty ? 'Untitled Workspace' : name.trim(),
      description: description.trim(),
      environments: [
        ApiEnvironment(id: '$id-local', name: 'Local', baseUrl: ''),
        ApiEnvironment(id: '$id-dev', name: 'Development', baseUrl: ''),
        ApiEnvironment(id: '$id-prod', name: 'Production', baseUrl: ''),
      ],
      activeEnvironmentId: '$id-local',
    );
    await _upsertWorkspace(workspace);
    await openWorkspace(workspace.id);
    return workspace;
  }

  Future<void> openWorkspace(String workspaceId) async {
    final workspace = state.workspaces
        .firstWhere((workspace) => workspace.id == workspaceId)
        .copyWith(lastUsedAt: DateTime.now());
    await _upsertWorkspace(workspace);
    final history = await ApiWorkspaceStorage.loadHistory(workspaceId);
    final reports = await ApiWorkspaceStorage.loadReports(workspaceId);
    final firstSelection = _firstRequestSelection(workspace);
    state = state.copyWith(
      activeWorkspaceId: workspaceId,
      selectedCollectionId:
          firstSelection.collectionId ?? workspace.collections.firstOrNull?.id,
      selectedFolderId: firstSelection.folderId,
      selectedRequestId: firstSelection.requestId,
      section: ApiWorkspaceSection.collections,
      response: null,
      history: history,
      reports: reports,
      runnerResult: reports.firstOrNull,
      temporaryVariables: const {},
      error: null,
    );
  }

  void closeWorkspace() {
    state = state.copyWith(
      activeWorkspaceId: null,
      selectedCollectionId: null,
      selectedFolderId: null,
      selectedRequestId: null,
      response: null,
      history: const [],
      reports: const [],
      runnerResult: null,
      temporaryVariables: const {},
      error: null,
    );
  }

  Future<void> renameWorkspace(String workspaceId, String name) async {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) return;
    await _upsertWorkspace(workspace.copyWith(name: name.trim()));
  }

  Future<void> updateWorkspace(ApiWorkspace workspace) async {
    await _upsertWorkspace(workspace);
  }

  Future<void> importWorkspace(ApiWorkspace workspace) async {
    final id = workspace.id.trim().isEmpty ||
            state.workspaces.any((item) => item.id == workspace.id)
        ? ApiWorkspaceIds.newId('workspace')
        : workspace.id;
    final imported = workspace.copyWith(
      id: id,
      name: workspace.name.trim().isEmpty
          ? 'Imported Workspace'
          : workspace.name.trim(),
      lastUsedAt: DateTime.now(),
    );
    await _upsertWorkspace(imported);
    await openWorkspace(imported.id);
  }

  Future<void> importCollection(ApiCollection collection) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) {
      await importWorkspace(
        ApiWorkspace(
          id: ApiWorkspaceIds.newId('workspace'),
          name: collection.name,
          collections: [collection],
        ),
      );
      return;
    }
    await _upsertWorkspace(
      workspace.copyWith(collections: [...workspace.collections, collection]),
    );
  }

  Future<void> toggleFavorite(String workspaceId) async {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) return;
    await _upsertWorkspace(workspace.copyWith(favorite: !workspace.favorite));
  }

  Future<void> archiveWorkspace(String workspaceId, bool archived) async {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) return;
    await _upsertWorkspace(workspace.copyWith(archived: archived));
    if (state.activeWorkspaceId == workspaceId && archived) closeWorkspace();
  }

  Future<void> duplicateWorkspace(String workspaceId) async {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) return;
    final copy =
        ApiWorkspace.fromMap(workspace.toMap(includeSecrets: true)).copyWith(
      id: ApiWorkspaceIds.newId('workspace'),
      name: '${workspace.name} Copy',
      favorite: false,
      archived: false,
      lastUsedAt: null,
    );
    await _upsertWorkspace(copy);
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    await ApiWorkspaceStorage.deleteWorkspace(workspaceId);
    final updated = state.workspaces
        .where((workspace) => workspace.id != workspaceId)
        .toList();
    state = state.copyWith(workspaces: updated);
    if (state.activeWorkspaceId == workspaceId) closeWorkspace();
  }

  Future<void> addCollection() async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    final collection = ApiCollection(
      id: ApiWorkspaceIds.newId('collection'),
      name: 'New Collection',
    );
    final updated =
        workspace.copyWith(collections: [...workspace.collections, collection]);
    await _upsertWorkspace(updated);
    state = state.copyWith(
      selectedCollectionId: collection.id,
      selectedFolderId: null,
      selectedRequestId: null,
    );
  }

  Future<void> addFolder() async {
    final workspace = state.activeWorkspace;
    final collection = state.selectedCollection;
    if (workspace == null) return;
    final targetCollection = collection ?? await _ensureCollection(workspace);
    final folder = ApiFolder(
      id: ApiWorkspaceIds.newId('folder'),
      name: 'New Folder',
    );
    final updatedCollection = targetCollection.copyWith(
      folders: [...targetCollection.folders, folder],
    );
    await _replaceCollection(updatedCollection);
    state = state.copyWith(
      selectedCollectionId: targetCollection.id,
      selectedFolderId: folder.id,
      selectedRequestId: null,
    );
  }

  Future<void> addRequest({bool inFolder = false}) async {
    var workspace = state.activeWorkspace;
    if (workspace == null) return;
    var collection = state.selectedCollection;
    collection ??= await _ensureCollection(workspace);
    workspace = state.activeWorkspace;
    if (workspace == null) return;

    final request = ApiRequestItem(
      id: ApiWorkspaceIds.newId('request'),
      name: 'New Request',
      method: 'GET',
      url: '{{baseUrl}}/',
    );
    final folder = inFolder ? state.selectedFolder : null;
    if (folder != null) {
      final updatedFolder =
          folder.copyWith(requests: [...folder.requests, request]);
      final updatedCollection = collection.copyWith(
        folders: [
          for (final item in collection.folders)
            if (item.id == folder.id) updatedFolder else item,
        ],
      );
      await _replaceCollection(updatedCollection);
      state = state.copyWith(selectedRequestId: request.id);
      return;
    }
    final updatedCollection = collection.copyWith(
      requests: [...collection.requests, request],
    );
    await _replaceCollection(updatedCollection);
    state = state.copyWith(
      selectedCollectionId: collection.id,
      selectedFolderId: null,
      selectedRequestId: request.id,
    );
  }

  void selectRequest({
    required String collectionId,
    String? folderId,
    required String requestId,
  }) {
    state = state.copyWith(
      selectedCollectionId: collectionId,
      selectedFolderId: folderId,
      selectedRequestId: requestId,
      section: ApiWorkspaceSection.collections,
      error: null,
    );
  }

  void selectFolder({
    required String collectionId,
    required String folderId,
  }) {
    state = state.copyWith(
      selectedCollectionId: collectionId,
      selectedFolderId: folderId,
      selectedRequestId: null,
      section: ApiWorkspaceSection.collections,
      error: null,
    );
  }

  Future<void> updateSelectedRequest(
    ApiRequestItem Function(ApiRequestItem request) update,
  ) async {
    final selected = state.selectedRequest;
    if (selected == null) return;
    await _replaceRequest(update(selected));
  }

  Future<void> duplicateSelectedRequest() async {
    final selected = state.selectedRequest;
    if (selected == null) return;
    final copy =
        ApiRequestItem.fromMap(selected.toMap(includeSecrets: true)).copyWith(
      id: ApiWorkspaceIds.newId('request'),
      name: '${selected.name} Copy',
    );
    final folder = state.selectedFolder;
    if (folder != null) {
      await _replaceFolder(
          folder.copyWith(requests: [...folder.requests, copy]));
    } else {
      final collection = state.selectedCollection;
      if (collection == null) return;
      await _replaceCollection(
        collection.copyWith(requests: [...collection.requests, copy]),
      );
    }
    state = state.copyWith(selectedRequestId: copy.id);
  }

  Future<void> deleteSelectedRequest() async {
    final selected = state.selectedRequest;
    final collection = state.selectedCollection;
    if (selected == null || collection == null) return;
    final folder = state.selectedFolder;
    if (folder != null) {
      await _replaceFolder(
        folder.copyWith(
          requests: folder.requests
              .where((request) => request.id != selected.id)
              .toList(),
        ),
      );
    } else {
      await _replaceCollection(
        collection.copyWith(
          requests: collection.requests
              .where((request) => request.id != selected.id)
              .toList(),
        ),
      );
    }
    state = state.copyWith(selectedRequestId: null, response: null);
  }

  Future<void> moveSelectedRequestToFolder(String? targetFolderId) async {
    final request = state.selectedRequest;
    final collection = state.selectedCollection;
    if (request == null || collection == null) return;
    var requests = collection.requests
        .where((item) => item.id != request.id)
        .toList(growable: true);
    var folders = [
      for (final folder in collection.folders)
        folder.copyWith(
          requests: folder.requests
              .where((item) => item.id != request.id)
              .toList(growable: true),
        ),
    ];
    if (targetFolderId == null) {
      requests = [...requests, request];
    } else {
      folders = [
        for (final folder in folders)
          if (folder.id == targetFolderId)
            folder.copyWith(requests: [...folder.requests, request])
          else
            folder,
      ];
    }
    await _replaceCollection(
      collection.copyWith(requests: requests, folders: folders),
    );
    state = state.copyWith(
      selectedFolderId: targetFolderId,
      selectedRequestId: request.id,
    );
  }

  Future<void> saveHistoryItemAsRequest(ApiHistoryItem item) async {
    var workspace = state.activeWorkspace;
    if (workspace == null) return;
    var collection = state.selectedCollection;
    collection ??= await _ensureCollection(workspace);
    final request = item.request.copyWith(
      id: ApiWorkspaceIds.newId('request'),
      name: item.requestName.isEmpty ? 'Saved from History' : item.requestName,
    );
    await _replaceCollection(
      collection.copyWith(requests: [...collection.requests, request]),
    );
    state = state.copyWith(
      selectedCollectionId: collection.id,
      selectedFolderId: null,
      selectedRequestId: request.id,
      section: ApiWorkspaceSection.collections,
    );
  }

  Future<void> updateEnvironment(ApiEnvironment environment) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    final exists =
        workspace.environments.any((item) => item.id == environment.id);
    final environments = exists
        ? [
            for (final item in workspace.environments)
              if (item.id == environment.id) environment else item,
          ]
        : [...workspace.environments, environment];
    await _upsertWorkspace(workspace.copyWith(environments: environments));
  }

  Future<void> selectEnvironment(String environmentId) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    await _upsertWorkspace(
      workspace.copyWith(activeEnvironmentId: environmentId),
    );
  }

  Future<void> setWorkspaceVariables(List<ApiVariable> variables) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    await _upsertWorkspace(workspace.copyWith(variables: variables));
  }

  Future<void> setTemporaryVariable(String key, String value) async {
    final variables = {...state.temporaryVariables};
    variables[key] = value;
    state = state.copyWith(temporaryVariables: variables);
  }

  ApiPreparedRequest? previewSelectedRequest() {
    final workspace = state.activeWorkspace;
    final request = state.selectedRequest;
    if (workspace == null || request == null) return null;
    return ApiWorkspaceRequestComposer.prepare(
      workspace: workspace,
      collection: state.selectedCollection,
      folder: state.selectedFolder,
      request: request,
      temporaryVariables: state.temporaryVariables,
    );
  }

  Future<void> sendSelectedRequest({bool allowUnresolved = false}) async {
    final workspace = state.activeWorkspace;
    final request = state.selectedRequest;
    if (workspace == null || request == null) {
      state = state.copyWith(error: 'Select or create a request first.');
      return;
    }
    final prepared = previewSelectedRequest();
    if (prepared == null) return;
    if (prepared.hasUnresolvedVariables && !allowUnresolved) {
      state = state.copyWith(
        error:
            'Unresolved variables: ${prepared.unresolvedVariables.join(', ')}',
      );
      return;
    }

    final client = http.Client();
    _activeClient = client;
    state = state.copyWith(sending: true, error: null);
    try {
      final response = await _executePrepared(
        workspace: workspace,
        prepared: prepared,
        client: client,
      );
      state = state.copyWith(response: response);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      client.close();
      if (_activeClient == client) _activeClient = null;
      state = state.copyWith(sending: false);
      await _refreshHistoryAndReports(workspace.id);
    }
  }

  void cancelRequest() {
    _activeClient?.close();
    _activeClient = null;
    state = state.copyWith(sending: false, runnerRunning: false);
  }

  Future<void> clearHistory() async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    await ApiWorkspaceStorage.clearWorkspaceHistory(workspace.id);
    state = state.copyWith(history: const []);
  }

  Future<void> runSelectedCollection({
    bool stopOnFailure = true,
    int delayMs = 0,
  }) async {
    final workspace = state.activeWorkspace;
    final collection = state.selectedCollection;
    if (workspace == null || collection == null) {
      state = state.copyWith(error: 'Select a collection to run.');
      return;
    }
    final items = _requestRunItems(collection);
    if (items.isEmpty) {
      state = state.copyWith(error: 'Collection has no requests to run.');
      return;
    }
    final client = http.Client();
    _activeClient = client;
    state = state.copyWith(runnerRunning: true, error: null);
    final startedAt = DateTime.now();
    final results = <ApiRunnerRequestResult>[];
    var shouldSkip = false;
    try {
      for (final item in items) {
        if (shouldSkip) {
          results.add(
            ApiRunnerRequestResult(
              requestId: item.request.id,
              requestName: item.request.name,
              passed: false,
              skipped: true,
              message: 'Skipped after previous failure.',
            ),
          );
          continue;
        }
        final prepared = ApiWorkspaceRequestComposer.prepare(
          workspace: workspace,
          collection: collection,
          folder: item.folder,
          request: item.request,
          temporaryVariables: state.temporaryVariables,
        );
        if (prepared.hasUnresolvedVariables) {
          results.add(
            ApiRunnerRequestResult(
              requestId: item.request.id,
              requestName: item.request.name,
              passed: false,
              message:
                  'Unresolved variables: ${prepared.unresolvedVariables.join(', ')}',
            ),
          );
          shouldSkip = stopOnFailure;
          continue;
        }
        try {
          final response = await _executePrepared(
            workspace: workspace,
            prepared: prepared,
            client: client,
            collection: collection,
            folder: item.folder,
          );
          final passed = response.passedAssertions &&
              response.statusCode >= 200 &&
              response.statusCode < 400;
          results.add(
            ApiRunnerRequestResult(
              requestId: item.request.id,
              requestName: item.request.name,
              passed: passed,
              statusCode: response.statusCode,
              durationMs: response.durationMs,
              message: passed ? 'Passed' : 'Failed',
            ),
          );
          if (!passed && stopOnFailure) shouldSkip = true;
        } catch (e) {
          results.add(
            ApiRunnerRequestResult(
              requestId: item.request.id,
              requestName: item.request.name,
              passed: false,
              message: e.toString(),
            ),
          );
          if (stopOnFailure) shouldSkip = true;
        }
        if (delayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
      final report = ApiRunnerResult(
        id: ApiWorkspaceIds.newId('run'),
        workspaceId: workspace.id,
        collectionId: collection.id,
        targetName: collection.name,
        environmentId: workspace.activeEnvironment?.id ?? '',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        results: results,
      );
      await ApiWorkspaceStorage.saveReport(report);
      state = state.copyWith(runnerResult: report);
    } finally {
      client.close();
      if (_activeClient == client) _activeClient = null;
      state = state.copyWith(runnerRunning: false);
      await _refreshHistoryAndReports(workspace.id);
    }
  }

  Future<ApiResponseRecord> _executePrepared({
    required ApiWorkspace workspace,
    required ApiPreparedRequest prepared,
    required http.Client client,
    ApiCollection? collection,
    ApiFolder? folder,
  }) async {
    var response = await ApiWorkspaceExecutor.execute(
      prepared: prepared,
      client: client,
    );
    final assertionResults = ApiAssertionEvaluator.evaluate(
      prepared.source.assertions,
      response,
    );
    final extractionResults = ApiExtractionEvaluator.extract(
      prepared.source.extractionRules,
      response,
    );
    response = response.copyWith(
      assertionResults: assertionResults,
      extractionResults: extractionResults,
    );
    await _applyExtractions(
      workspace: workspace,
      request: prepared.source,
      extractionResults: extractionResults,
    );
    final history = ApiHistoryItem(
      id: ApiWorkspaceIds.newId('history'),
      workspaceId: workspace.id,
      requestId: prepared.source.id,
      requestName: prepared.source.name,
      method: prepared.method,
      url: response.url,
      statusCode: response.statusCode,
      durationMs: response.durationMs,
      request: prepared.source,
      response: response,
    );
    await ApiWorkspaceStorage.saveHistory(
      workspace.saveSecrets ? history : history.sanitized(),
    );
    await _upsertWorkspace(workspace.copyWith(lastUsedAt: DateTime.now()));
    return response;
  }

  Future<void> _applyExtractions({
    required ApiWorkspace workspace,
    required ApiRequestItem request,
    required List<ApiExtractionResult> extractionResults,
  }) async {
    if (extractionResults.isEmpty) return;
    final rules = {
      for (final rule in request.extractionRules) rule.id: rule,
    };
    var temporary = {...state.temporaryVariables};
    var updatedWorkspace = workspace;
    for (final result in extractionResults.where((result) => result.success)) {
      final rule = rules[result.ruleId];
      final key = result.variableName.trim();
      if (key.isEmpty || rule == null) continue;
      if (result.isSecret &&
          rule.targetScope != ApiVariableScope.temporary &&
          !workspace.saveSecrets) {
        temporary[key] = result.value;
        continue;
      }
      switch (rule.targetScope) {
        case ApiVariableScope.temporary:
          temporary[key] = result.value;
          break;
        case ApiVariableScope.workspace:
          updatedWorkspace = updatedWorkspace.copyWith(
            variables: _upsertVariable(
              updatedWorkspace.variables,
              ApiVariable(
                key: key,
                value: result.value,
                isSecret: result.isSecret,
              ),
            ),
          );
          break;
        case ApiVariableScope.environment:
          final environment = updatedWorkspace.activeEnvironment;
          if (environment == null) {
            temporary[key] = result.value;
          } else {
            final updatedEnvironment = environment.copyWith(
              variables: _upsertVariable(
                environment.variables,
                ApiVariable(
                  key: key,
                  value: result.value,
                  isSecret: result.isSecret,
                ),
              ),
            );
            updatedWorkspace = updatedWorkspace.copyWith(
              environments: [
                for (final item in updatedWorkspace.environments)
                  if (item.id == updatedEnvironment.id)
                    updatedEnvironment
                  else
                    item,
              ],
            );
          }
          break;
      }
    }
    state = state.copyWith(temporaryVariables: temporary);
    await _upsertWorkspace(updatedWorkspace);
  }

  Future<void> _refreshHistoryAndReports(String workspaceId) async {
    final history = await ApiWorkspaceStorage.loadHistory(workspaceId);
    final reports = await ApiWorkspaceStorage.loadReports(workspaceId);
    state = state.copyWith(history: history, reports: reports);
  }

  Future<ApiCollection> _ensureCollection(ApiWorkspace workspace) async {
    if (workspace.collections.isNotEmpty) return workspace.collections.first;
    final collection = ApiCollection(
      id: ApiWorkspaceIds.newId('collection'),
      name: 'Default Collection',
    );
    await _upsertWorkspace(
      workspace.copyWith(collections: [collection]),
    );
    return collection;
  }

  Future<void> _replaceRequest(ApiRequestItem updatedRequest) async {
    final collection = state.selectedCollection;
    if (collection == null) return;
    final folder = state.selectedFolder;
    if (folder != null) {
      await _replaceFolder(
        folder.copyWith(
          requests: [
            for (final request in folder.requests)
              if (request.id == updatedRequest.id) updatedRequest else request,
          ],
        ),
      );
      return;
    }
    await _replaceCollection(
      collection.copyWith(
        requests: [
          for (final request in collection.requests)
            if (request.id == updatedRequest.id) updatedRequest else request,
        ],
      ),
    );
  }

  Future<void> _replaceFolder(ApiFolder updatedFolder) async {
    final collection = state.selectedCollection;
    if (collection == null) return;
    await _replaceCollection(
      collection.copyWith(
        folders: [
          for (final folder in collection.folders)
            if (folder.id == updatedFolder.id) updatedFolder else folder,
        ],
      ),
    );
  }

  Future<void> _replaceCollection(ApiCollection updatedCollection) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    await _upsertWorkspace(
      workspace.copyWith(
        collections: [
          for (final collection in workspace.collections)
            if (collection.id == updatedCollection.id)
              updatedCollection
            else
              collection,
        ],
      ),
    );
  }

  Future<void> _upsertWorkspace(ApiWorkspace workspace) async {
    final updated = [
      for (final item in state.workspaces)
        if (item.id == workspace.id) workspace else item,
      if (!state.workspaces.any((item) => item.id == workspace.id)) workspace,
    ];
    await ApiWorkspaceStorage.saveWorkspace(workspace);
    updated.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final aDate = a.lastUsedAt ?? a.updatedAt;
      final bDate = b.lastUsedAt ?? b.updatedAt;
      return bDate.compareTo(aDate);
    });
    state = state.copyWith(workspaces: updated);
  }

  ApiWorkspace? _workspaceById(String workspaceId) {
    for (final workspace in state.workspaces) {
      if (workspace.id == workspaceId) return workspace;
    }
    return null;
  }

  ({String? collectionId, String? folderId, String? requestId})
      _firstRequestSelection(ApiWorkspace workspace) {
    for (final collection in workspace.collections) {
      if (collection.requests.isNotEmpty) {
        return (
          collectionId: collection.id,
          folderId: null,
          requestId: collection.requests.first.id,
        );
      }
      for (final folder in collection.folders) {
        if (folder.requests.isNotEmpty) {
          return (
            collectionId: collection.id,
            folderId: folder.id,
            requestId: folder.requests.first.id,
          );
        }
      }
    }
    return (collectionId: null, folderId: null, requestId: null);
  }

  List<_RunItem> _requestRunItems(ApiCollection collection) {
    return [
      for (final request in collection.requests) _RunItem(request: request),
      for (final folder in collection.folders)
        for (final request in folder.requests)
          _RunItem(folder: folder, request: request),
    ];
  }

  static List<ApiVariable> _upsertVariable(
    List<ApiVariable> variables,
    ApiVariable variable,
  ) {
    final exists = variables.any((item) => item.key == variable.key);
    if (!exists) return [...variables, variable];
    return [
      for (final item in variables)
        if (item.key == variable.key) variable else item,
    ];
  }
}

class _RunItem {
  final ApiFolder? folder;
  final ApiRequestItem request;

  const _RunItem({this.folder, required this.request});
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
