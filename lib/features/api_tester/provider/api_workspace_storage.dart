import '../../../core/storage/local_storage.dart';
import '../models/api_history_entry.dart';
import '../models/api_request.dart';
import '../models/api_workspace_models.dart';
import '../utils/api_workspace_executor.dart';

class ApiWorkspaceStorage {
  static const _legacyMigratedKey = 'legacy_api_history_migrated';
  static const _legacyWorkspaceId = 'legacy-api-history';

  static Future<List<ApiWorkspace>> loadWorkspaces() async {
    await migrateLegacyHistoryIfNeeded();
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    final workspaces = box.values
        .whereType<Map>()
        .map((value) => ApiWorkspace.fromMap(Map<String, dynamic>.from(value)))
        .toList();
    workspaces.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final aUsed = a.lastUsedAt ?? a.updatedAt;
      final bUsed = b.lastUsedAt ?? b.updatedAt;
      return bUsed.compareTo(aUsed);
    });
    return workspaces;
  }

  static Future<void> saveWorkspace(ApiWorkspace workspace) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    await box.put(workspace.id, workspace.toMap(includeSecrets: true));
  }

  static Future<void> deleteWorkspace(String workspaceId) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    await box.delete(workspaceId);
    await clearWorkspaceHistory(workspaceId);
  }

  static Future<List<ApiHistoryItem>> loadHistory(String workspaceId) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceHistoryBox);
    final history = box.values
        .whereType<Map>()
        .map(
            (value) => ApiHistoryItem.fromMap(Map<String, dynamic>.from(value)))
        .where((item) => item.workspaceId == workspaceId)
        .toList();
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  static Future<void> saveHistory(ApiHistoryItem item) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceHistoryBox);
    await box.put(item.id, item.toMap(includeSecrets: true));
  }

  static Future<void> clearWorkspaceHistory(String workspaceId) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceHistoryBox);
    final keys = box.keys.where((key) {
      final value = box.get(key);
      if (value is! Map) return false;
      return value['workspaceId'] == workspaceId;
    }).toList();
    for (final key in keys) {
      await box.delete(key);
    }
  }

  static Future<List<ApiRunnerResult>> loadReports(String workspaceId) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceReportsBox);
    final reports = box.values
        .whereType<Map>()
        .map((value) =>
            ApiRunnerResult.fromMap(Map<String, dynamic>.from(value)))
        .where((report) => report.workspaceId == workspaceId)
        .toList();
    reports.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return reports;
  }

  static Future<void> saveReport(ApiRunnerResult report) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceReportsBox);
    await box.put(report.id, report.toMap());
  }

  static Future<void> migrateLegacyHistoryIfNeeded() async {
    final meta = await LocalStorage.openBox<dynamic>(
      LocalStorage.apiWorkspaceMetaBox,
    );
    if (meta.get(_legacyMigratedKey) == true) return;

    final legacyHistory =
        await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
    if (legacyHistory.isEmpty) {
      await meta.put(_legacyMigratedKey, true);
      return;
    }

    final workspaceBox =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    if (workspaceBox.containsKey(_legacyWorkspaceId)) {
      await meta.put(_legacyMigratedKey, true);
      return;
    }

    final entries = legacyHistory.values
        .whereType<Map>()
        .map((value) => ApiHistoryEntry(
              key: null,
              request: ApiRequest.fromMap(Map<String, dynamic>.from(value)),
            ))
        .toList();
    entries.sort((a, b) => a.request.timestamp.compareTo(b.request.timestamp));

    final requests = <ApiRequestItem>[];
    for (final entry in entries) {
      final request = entry.request;
      requests.add(
        ApiRequestItem(
          id: ApiWorkspaceIds.newId('legacy-request'),
          name: '${request.method} ${request.url}',
          method: request.method,
          url: request.url,
          headers: request.headers,
          queryParams: request.queryParams,
          body: ApiRequestBody(
            type: (request.body ?? '').trim().isEmpty
                ? ApiRequestBodyType.none
                : ApiRequestBodyType.rawText,
            raw: request.body ?? '',
          ),
          createdAt: request.timestamp,
          updatedAt: request.timestamp,
        ),
      );
    }

    final now = DateTime.now();
    final workspace = ApiWorkspace(
      id: _legacyWorkspaceId,
      name: 'Legacy API History',
      description:
          'Requests copied from the original API Tester history. The old history box is preserved.',
      createdAt: now,
      updatedAt: now,
      collections: [
        ApiCollection(
          id: 'legacy-api-history-collection',
          name: 'Imported History',
          requests: requests,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await workspaceBox.put(workspace.id, workspace.toMap());
    await meta.put(_legacyMigratedKey, true);
  }
}
