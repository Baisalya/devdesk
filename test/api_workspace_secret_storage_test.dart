import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/security/secure_secret_store.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/provider/api_workspace_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('devdesk/secure_secrets');
  const canary = 'CANARY_SECRET_4f9c21';
  final protectedValues = <String, String>{};
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('devdesk_secret_store_');
    LocalStorage.initializeForTest(directory.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(
        (call.arguments as Map?) ?? const {},
      );
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'write':
          protectedValues[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return protectedValues[args['key'] as String];
        case 'delete':
          protectedValues.remove(args['key'] as String);
          return null;
        case 'clearAll':
          protectedValues.clear();
          return null;
      }
      throw PlatformException(code: 'unsupported');
    });
  });

  setUp(() async {
    protectedValues.clear();
    await LocalStorage.clearAll();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await LocalStorage.closeAll();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('secrets are stored as a protected overlay, not ordinary Hive data',
      () async {
    final request = ApiRequestItem(
      id: 'request-1',
      name: 'Protected request',
      method: 'POST',
      url: 'https://example.test?token=$canary',
      headers: {'Authorization': 'Bearer $canary'},
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: canary,
      ),
      body: ApiRequestBody(
        type: ApiRequestBodyType.rawJson,
        raw: '{"password":"$canary"}',
      ),
    );
    final workspace = ApiWorkspace(
      id: 'workspace-1',
      name: 'Ordinary workspace metadata',
      saveSecrets: true,
      auth: const ApiAuthConfig(
        type: ApiAuthType.apiKeyHeader,
        apiKeyName: 'X-Api-Key',
        apiKeyValue: canary,
      ),
      collections: [
        ApiCollection(
          id: 'collection-1',
          name: 'Collection',
          requests: [request],
        ),
      ],
    );

    final warning = await ApiWorkspaceStorage.saveWorkspace(workspace);
    expect(warning, isNull);

    final ordinary =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    final ordinaryText = jsonEncode(ordinary.get(workspace.id));
    expect(ordinaryText, isNot(contains(canary)));
    expect(ordinaryText, contains('Ordinary workspace metadata'));
    expect((ordinary.get(workspace.id) as Map)['saveSecrets'], isTrue);

    final protectedText =
        protectedValues[SecureSecretStore.workspaceKey(workspace.id)]!;
    final protected = jsonDecode(protectedText) as Map<String, dynamic>;
    expect(protected['schemaVersion'], 1);
    expect(protected['workspaceId'], workspace.id);
    expect(protectedText, contains(canary));
    expect(protectedText, isNot(contains('Ordinary workspace metadata')));

    final loaded = await ApiWorkspaceStorage.loadWorkspaces();
    final restored = loaded.singleWhere((item) => item.id == workspace.id);
    expect(restored.auth.apiKeyValue, canary);
    final restoredRequest = restored.collections.single.requests.single;
    expect(restoredRequest.auth.token, canary);
    expect(restoredRequest.headers['Authorization'], 'Bearer $canary');
    expect(
      restoredRequest.body.raw,
      contains(canary),
    );
    expect(restored.saveSecrets, isTrue);

    final backup = jsonEncode(await LocalStorage.exportBackupDocument());
    expect(backup, isNot(contains(canary)));
  });

  test('an opted-out workspace never reloads a stale protected overlay',
      () async {
    final workspace = ApiWorkspace(
      id: 'workspace-opt-out',
      name: 'Opt out',
      saveSecrets: true,
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: canary,
      ),
    );
    await ApiWorkspaceStorage.saveWorkspace(workspace);
    final key = SecureSecretStore.workspaceKey(workspace.id);
    expect(protectedValues, contains(key));

    // This is the durable state left when a protected-value deletion fails:
    // the ordinary workspace records the opt-out, while an obsolete encrypted
    // value can still exist. Loading must honor the ordinary opt-out.
    final ordinary =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    await ordinary.put(
      workspace.id,
      workspace.sanitized().copyWith(saveSecrets: false).toMap(),
    );

    final loaded = await ApiWorkspaceStorage.loadWorkspaces();
    final restored = loaded.singleWhere((item) => item.id == workspace.id);
    expect(restored.saveSecrets, isFalse);
    expect(restored.auth.token, isEmpty);
    expect(protectedValues, isNot(contains(key)));
  });

  test('legacy plaintext secrets are removed when protected storage is absent',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return false;
      return null;
    });
    final box = await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    final legacy = ApiWorkspace(
      id: 'legacy-workspace',
      name: 'Legacy',
      saveSecrets: true,
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: canary,
      ),
    );
    await box.put(legacy.id, legacy.toMap(includeSecrets: true));

    final loaded = await ApiWorkspaceStorage.loadWorkspaces();
    expect(loaded.single.auth.token, isEmpty);
    expect(jsonEncode(box.get(legacy.id)), isNot(contains(canary)));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(
        (call.arguments as Map?) ?? const {},
      );
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'write':
          protectedValues[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return protectedValues[args['key'] as String];
        case 'delete':
          protectedValues.remove(args['key'] as String);
          return null;
        case 'clearAll':
          protectedValues.clear();
          return null;
      }
      return null;
    });
  });

  test('damaged workspace records are quarantined and removed', () async {
    final workspaces =
        await LocalStorage.openBox<Map>(LocalStorage.apiWorkspacesBox);
    await workspaces.put('damaged-workspace', {
      'id': {'unexpected': 'map'},
      'name': 'Damaged record',
    });

    final loaded = await ApiWorkspaceStorage.loadWorkspaces();
    expect(loaded, isEmpty);
    expect(workspaces.containsKey('damaged-workspace'), isFalse);

    final quarantine =
        await LocalStorage.openBox<Map>(LocalStorage.quarantineBox);
    expect(quarantine, hasLength(1));
    final record = Map<String, dynamic>.from(quarantine.values.single);
    expect(record['box'], LocalStorage.apiWorkspacesBox);
    expect(record['recordKey'], 'damaged-workspace');
  });
}
