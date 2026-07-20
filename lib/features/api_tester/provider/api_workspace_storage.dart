import '../../../core/security/data_redactor.dart';
import '../../../core/security/secure_secret_store.dart';
import '../../../core/storage/local_storage.dart';
import '../models/api_history_entry.dart';
import '../models/api_request.dart';
import '../models/api_workspace_models.dart';
import '../utils/api_workspace_executor.dart';

class ApiWorkspaceStorage {
  static const _legacyMigratedKey = 'legacy_api_history_migrated';
  static const _legacyWorkspaceId = 'legacy-api-history';
  static const _secretEnvelopeVersion = 1;

  static const _secretMigrationWarningsKey = 'secret_migration_warnings';

  static Future<List<ApiWorkspace>> loadWorkspaces() async {
    await migrateLegacyHistoryIfNeeded();
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    final meta = await LocalStorage.openBox<dynamic>(
      LocalStorage.apiWorkspaceMetaBox,
    );
    final protectedStorageAvailable = await SecureSecretStore.isAvailable();
    final warnings = <String>[];
    final workspaces = <ApiWorkspace>[];
    for (final key in box.keys.toList(growable: false)) {
      final value = box.get(key);
      if (value is! Map) continue;
      final stored = Map<String, dynamic>.from(value);
      ApiWorkspace workspace;
      try {
        workspace = ApiWorkspace.fromMap(stored);
      } catch (_) {
        await LocalStorage.quarantineRecord(
          boxName: LocalStorage.apiWorkspacesBox,
          recordKey: key.toString(),
          value: stored,
        );
        warnings.add('One damaged API workspace was moved to quarantine.');
        continue;
      }

      var migratedPlaintextSecrets = false;
      if (workspace.hasSecrets) {
        if (workspace.saveSecrets && protectedStorageAvailable) {
          try {
            // Migrate legacy plaintext only after the protected copy commits.
            await SecureSecretStore.writeJson(
              SecureSecretStore.workspaceKey(workspace.id),
              _createSecretEnvelope(workspace),
            );
            await box.put(
              workspace.id,
              _ordinaryWorkspaceMap(workspace, saveSecrets: true),
            );
            migratedPlaintextSecrets = true;
          } catch (_) {
            workspace = workspace.sanitized();
            await box.put(
              workspace.id,
              _ordinaryWorkspaceMap(workspace, saveSecrets: false),
            );
            warnings.add(
              'Saved secrets for "${workspace.name}" could not be protected and were removed from ordinary storage. Re-enter them if needed.',
            );
          }
        } else {
          workspace = workspace.sanitized();
          await box.put(
            workspace.id,
            _ordinaryWorkspaceMap(workspace, saveSecrets: false),
          );
          warnings.add(
            protectedStorageAvailable
                ? 'Unprotected legacy secrets for "${workspace.name}" were removed because secret saving was disabled.'
                : 'Protected secret storage is unavailable on this platform. Saved secrets for "${workspace.name}" were removed; use session-only values.',
          );
        }
      }

      if (protectedStorageAvailable && workspace.saveSecrets) {
        try {
          if (!migratedPlaintextSecrets) {
            final protected = await SecureSecretStore.readJson(
              SecureSecretStore.workspaceKey(workspace.id),
            );
            if (protected != null) {
              if (protected['schemaVersion'] == _secretEnvelopeVersion) {
                workspace = _applySecretEnvelope(workspace, protected);
              } else {
                // One-time compatibility with the earlier whole-workspace
                // vault representation. Rewrite it immediately as a
                // secret-only overlay.
                final restored = ApiWorkspace.fromMap(protected);
                if (restored.id != workspace.id) {
                  throw const FormatException(
                    'Protected workspace identity does not match.',
                  );
                }
                await SecureSecretStore.writeJson(
                  SecureSecretStore.workspaceKey(workspace.id),
                  _createSecretEnvelope(restored),
                );
                workspace = restored;
              }
            } else {
              workspace = workspace.copyWith(saveSecrets: false);
              await box.put(
                workspace.id,
                _ordinaryWorkspaceMap(workspace, saveSecrets: false),
              );
              warnings.add(
                'Protected secrets for "${workspace.name}" are missing. Secret saving was disabled for this workspace.',
              );
            }
          }
        } catch (_) {
          // Never keep a secret-bearing Hive fallback or an enabled flag after
          // a protection/read error.
          workspace = workspace.sanitized();
          await box.put(
            workspace.id,
            _ordinaryWorkspaceMap(workspace, saveSecrets: false),
          );
          warnings.add(
            'Saved secrets for "${workspace.name}" could not be restored and were removed from ordinary storage. Re-enter them if needed.',
          );
        }
      } else if (workspace.saveSecrets) {
        workspace = workspace.sanitized();
        await box.put(
          workspace.id,
          _ordinaryWorkspaceMap(workspace, saveSecrets: false),
        );
        warnings.add(
          'Protected secret storage is unavailable on this platform. Saved secrets for "${workspace.name}" were removed; use session-only values.',
        );
      } else if (protectedStorageAvailable) {
        // A previous delete may have failed. Never read a protected overlay
        // when the ordinary workspace explicitly opts out; retry deletion.
        try {
          await SecureSecretStore.delete(
            SecureSecretStore.workspaceKey(workspace.id),
          );
        } catch (_) {
          warnings.add(
            'An obsolete protected secret copy for "${workspace.name}" could not be removed. It was not loaded.',
          );
        }
      }
      workspaces.add(workspace);
    }
    if (warnings.isNotEmpty) {
      await meta.put(_secretMigrationWarningsKey, warnings.toSet().toList());
    }
    workspaces.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final aUsed = a.lastUsedAt ?? a.updatedAt;
      final bUsed = b.lastUsedAt ?? b.updatedAt;
      return bUsed.compareTo(aUsed);
    });
    return workspaces;
  }

  static Future<List<String>> consumeWarnings() async {
    final meta = await LocalStorage.openBox<dynamic>(
      LocalStorage.apiWorkspaceMetaBox,
    );
    final raw = meta.get(_secretMigrationWarningsKey);
    await meta.delete(_secretMigrationWarningsKey);
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  static Future<String?> saveWorkspace(ApiWorkspace workspace) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    final secretKey = SecureSecretStore.workspaceKey(workspace.id);
    final protectedStorageAvailable = await SecureSecretStore.isAvailable();
    String? warning;
    var persistSecretPreference = false;
    if (workspace.saveSecrets && workspace.hasSecrets) {
      if (protectedStorageAvailable) {
        try {
          await SecureSecretStore.writeJson(
            secretKey,
            _createSecretEnvelope(workspace),
          );
          persistSecretPreference = true;
        } catch (_) {
          warning =
              'Secrets remain available for this session but could not be saved securely. Re-enter them after restart.';
          try {
            await SecureSecretStore.delete(secretKey);
          } catch (_) {
            // The ordinary workspace remains opted out, so stale protected
            // data can never be re-applied by loadWorkspaces.
          }
        }
      } else {
        warning =
            'Protected secret storage is unavailable on this platform. Secrets are session-only and were not saved.';
      }
    } else {
      try {
        await SecureSecretStore.delete(secretKey);
      } catch (_) {
        warning =
            'The protected secret copy could not be removed. Clear local data before sharing this device.';
      }
    }
    await box.put(
      workspace.id,
      _ordinaryWorkspaceMap(
        workspace,
        saveSecrets: persistSecretPreference,
      ),
    );
    return warning;
  }

  static Future<void> deleteWorkspace(String workspaceId) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    await box.delete(workspaceId);
    await SecureSecretStore.delete(SecureSecretStore.workspaceKey(workspaceId));
    await clearWorkspaceHistory(workspaceId);
  }

  static Map<String, dynamic> _createSecretEnvelope(ApiWorkspace workspace) {
    final original = workspace.toMap(includeSecrets: true);
    final sanitized = workspace.sanitized().toMap(includeSecrets: false);
    final values = <Map<String, dynamic>>[];
    _collectSecretDifferences(original, sanitized, const [], values);
    return {
      'schemaVersion': _secretEnvelopeVersion,
      'workspaceId': workspace.id,
      'values': values,
    };
  }

  static Map<String, dynamic> _ordinaryWorkspaceMap(
    ApiWorkspace workspace, {
    required bool saveSecrets,
  }) {
    final sanitized = workspace.sanitized().copyWith(
          saveSecrets: saveSecrets,
        );
    return sanitized.toMap(includeSecrets: true);
  }

  static ApiWorkspace _applySecretEnvelope(
    ApiWorkspace workspace,
    Map<String, dynamic> envelope,
  ) {
    if (envelope['workspaceId'] != workspace.id ||
        envelope['values'] is! List) {
      throw const FormatException('Protected secret data is invalid.');
    }
    final restored = _deepCopy(workspace.toMap(includeSecrets: false));
    for (final rawEntry in envelope['values'] as List) {
      if (rawEntry is! Map || rawEntry['path'] is! List) {
        throw const FormatException('Protected secret entry is invalid.');
      }
      final path = (rawEntry['path'] as List).toList(growable: false);
      if (path.isEmpty || path.length > 64) {
        throw const FormatException('Protected secret path is invalid.');
      }
      _writePath(restored, path, rawEntry['value']);
    }
    final result = ApiWorkspace.fromMap(Map<String, dynamic>.from(restored));
    if (result.id != workspace.id) {
      throw const FormatException('Protected workspace identity changed.');
    }
    return result;
  }

  static void _collectSecretDifferences(
    dynamic original,
    dynamic sanitized,
    List<dynamic> path,
    List<Map<String, dynamic>> output,
  ) {
    if (original is Map && sanitized is Map) {
      for (final entry in original.entries) {
        if (!sanitized.containsKey(entry.key)) {
          output.add({
            'path': [...path, entry.key.toString()],
            'value': entry.value,
          });
          continue;
        }
        _collectSecretDifferences(
          entry.value,
          sanitized[entry.key],
          [...path, entry.key.toString()],
          output,
        );
      }
      return;
    }
    if (original is List && sanitized is List) {
      final count = original.length < sanitized.length
          ? original.length
          : sanitized.length;
      for (var index = 0; index < count; index++) {
        _collectSecretDifferences(
          original[index],
          sanitized[index],
          [...path, index],
          output,
        );
      }
      return;
    }
    if (original != sanitized) {
      output.add({'path': path, 'value': original});
    }
  }

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _deepCopy(entry.value),
      };
    }
    if (value is List) return value.map(_deepCopy).toList();
    return value;
  }

  static void _writePath(dynamic root, List<dynamic> path, dynamic value) {
    dynamic current = root;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      if (segment is String && current is Map) {
        if (!current.containsKey(segment)) {
          throw const FormatException('Protected secret path is stale.');
        }
        current = current[segment];
      } else if (segment is int && current is List) {
        if (segment < 0 || segment >= current.length) {
          throw const FormatException('Protected secret path is stale.');
        }
        current = current[segment];
      } else {
        throw const FormatException('Protected secret path is invalid.');
      }
    }
    final leaf = path.last;
    if (leaf is String && current is Map) {
      current[leaf] = _deepCopy(value);
      return;
    }
    if (leaf is int && current is List && leaf >= 0 && leaf < current.length) {
      current[leaf] = _deepCopy(value);
      return;
    }
    throw const FormatException('Protected secret path is stale.');
  }

  static Future<List<ApiHistoryItem>> loadHistory(String workspaceId) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceHistoryBox);
    final history = <ApiHistoryItem>[];
    for (final key in box.keys.toList(growable: false)) {
      final value = box.get(key);
      if (value is! Map) continue;
      try {
        final item = ApiHistoryItem.fromMap(
          Map<String, dynamic>.from(value),
        );
        if (item.workspaceId == workspaceId) history.add(item);
      } catch (_) {
        await LocalStorage.quarantineRecord(
          boxName: LocalStorage.apiWorkspaceHistoryBox,
          recordKey: key.toString(),
          value: value,
        );
      }
    }
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history.take(100).toList(growable: false);
  }

  static Future<void> saveHistory(ApiHistoryItem item) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceHistoryBox);
    await box.put(item.id, item.sanitized().toMap(includeSecrets: false));
    final matching = <MapEntry<dynamic, DateTime>>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map || value['workspaceId'] != item.workspaceId) continue;
      final timestamp = value['timestamp'];
      matching.add(MapEntry(
        key,
        DateTime.fromMillisecondsSinceEpoch(timestamp is int ? timestamp : 0),
      ));
    }
    matching.sort((a, b) => b.value.compareTo(a.value));
    for (final stale in matching.skip(100)) {
      await box.delete(stale.key);
    }
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
    final reports = <ApiRunnerResult>[];
    for (final key in box.keys.toList(growable: false)) {
      final value = box.get(key);
      if (value is! Map) continue;
      try {
        final report = ApiRunnerResult.fromMap(
          Map<String, dynamic>.from(value),
        );
        if (report.workspaceId == workspaceId) reports.add(report);
      } catch (_) {
        await LocalStorage.quarantineRecord(
          boxName: LocalStorage.apiWorkspaceReportsBox,
          recordKey: key.toString(),
          value: value,
        );
      }
    }
    reports.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return reports.take(50).toList(growable: false);
  }

  static Future<void> saveReport(ApiRunnerResult report) async {
    final box =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspaceReportsBox);
    final safe = DataRedactor.deepRedact(report.toMap());
    await box.put(report.id, Map<String, dynamic>.from(safe as Map));
    final matching = <MapEntry<dynamic, DateTime>>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map || value['workspaceId'] != report.workspaceId) continue;
      final timestamp = value['finishedAt'];
      matching.add(
        MapEntry(
          key,
          DateTime.fromMillisecondsSinceEpoch(timestamp is int ? timestamp : 0),
        ),
      );
    }
    matching.sort((a, b) => b.value.compareTo(a.value));
    for (final stale in matching.skip(50)) {
      await box.delete(stale.key);
    }
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
    await workspaceBox.put(
      workspace.id,
      _ordinaryWorkspaceMap(workspace, saveSecrets: false),
    );
    await meta.put(_legacyMigratedKey, true);
  }
}
