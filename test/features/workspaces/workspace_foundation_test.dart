import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/logging/structured_logger.dart';
import 'package:devdesk/core/security/data_redactor.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/workspaces/data/hive_workspace_repository.dart';
import 'package:devdesk/features/workspaces/data/local_workspace_file_system.dart';
import 'package:devdesk/features/workspaces/domain/workspace_file_system.dart';
import 'package:devdesk/features/workspaces/domain/workspace_models.dart';
import 'package:devdesk/features/workspaces/domain/workspace_repository.dart';
import 'package:devdesk/features/workspaces/provider/workspace_provider.dart';

void main() {
  late Directory storageDirectory;
  late Directory workspaceDirectory;

  setUpAll(() async {
    storageDirectory =
        await Directory.systemTemp.createTemp('devdesk_workspace_storage_');
    LocalStorage.initializeForTest(storageDirectory.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
    workspaceDirectory =
        await Directory.systemTemp.createTemp('devdesk_workspace_root_');
  });

  tearDown(() async {
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

  test('workspace model preserves root capabilities and portable metadata', () {
    final now = DateTime.utc(2026, 7, 22, 10, 30);
    final workspace = DeveloperWorkspace(
      id: 'workspace-1',
      name: 'Customer API',
      description: 'Local customer platform workspace',
      root: const WorkspaceRootRef(
        kind: WorkspaceRootKind.localPath,
        platform: WorkspacePlatform.windows,
        value: r'C:\projects\customer-api',
        displayPath: r'C:\projects\customer-api',
        capabilities: {
          WorkspaceCapability.read,
          WorkspaceCapability.write,
          WorkspaceCapability.gitCli,
        },
      ),
      kinds: const {WorkspaceKind.api, WorkspaceKind.git},
      createdAt: now,
      lastOpenedAt: now,
      pinned: true,
    );

    final restored = DeveloperWorkspace.fromMap(workspace.toMap());

    expect(restored.id, workspace.id);
    expect(restored.kinds, workspace.kinds);
    expect(restored.root.capabilities, workspace.root.capabilities);
    expect(restored.pinned, isTrue);
    expect(restored.createdAt, now);
  });

  test('local filesystem health probe never changes workspace source files',
      () async {
    final source =
        File('${workspaceDirectory.path}${Platform.pathSeparator}README.md');
    await source.writeAsString('# Owned by the user');
    final before =
        await workspaceDirectory.list().map((item) => item.path).toList();
    const fileSystem = LocalWorkspaceFileSystem();

    final root = await fileSystem.rootFromLocalPath(workspaceDirectory.path);
    final health = await fileSystem.inspect(root);
    final after =
        await workspaceDirectory.list().map((item) => item.path).toList();

    expect(health.rootAvailable, isTrue);
    expect(health.canRead, isTrue);
    expect(await source.readAsString(), '# Owned by the user');
    expect(after, unorderedEquals(before));
  });

  test('workspace filesystem bounds paths and supports safe create/read/list',
      () async {
    const fileSystem = LocalWorkspaceFileSystem();
    final root = await fileSystem.rootFromLocalPath(workspaceDirectory.path);

    await fileSystem.createFile(
      root,
      'new-note.md',
      Uint8List.fromList('# New note'.codeUnits),
    );
    final entries = await fileSystem.list(root);
    final content = await fileSystem.readBytes(root, 'new-note.md');

    expect(entries.map((entry) => entry.relativePath), contains('new-note.md'));
    expect(String.fromCharCodes(content), '# New note');
    expect(
      () => fileSystem.normalizeRelativePath('../outside.md'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      fileSystem.readBytes(root, '../outside.md'),
      throwsA(isA<Exception>()),
    );
  });

  test('removing registry metadata never deletes the workspace folder',
      () async {
    final source =
        File('${workspaceDirectory.path}${Platform.pathSeparator}keep.txt');
    await source.writeAsString('keep me');
    const fileSystem = LocalWorkspaceFileSystem();
    const repository = HiveWorkspaceRepository();
    final root = await fileSystem.rootFromLocalPath(workspaceDirectory.path);
    final now = DateTime.now().toUtc();
    final workspace = DeveloperWorkspace(
      id: 'workspace-safe-remove',
      name: 'Safe remove',
      root: root,
      createdAt: now,
      lastOpenedAt: now,
    );
    await repository.save(workspace);

    await repository.removeFromRegistry(workspace.id);

    expect(await repository.getById(workspace.id), isNull);
    expect(await workspaceDirectory.exists(), isTrue);
    expect(await source.readAsString(), 'keep me');
  });

  test('schema 2 to 3 migration is additive and preserves existing data',
      () async {
    final settings =
        await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    final meta =
        await LocalStorage.openBox<dynamic>(LocalStorage.storageMetaBox);
    await settings.put('legacy-setting', 'preserved');
    await meta.put('storage_schema_version', 2);

    final result = await LocalStorage.bootstrap();

    expect(result.isReady, isTrue);
    expect(settings.get('legacy-setting'), 'preserved');
    expect(meta.get('storage_schema_version'), 3);
    expect(
      await LocalStorage.openBox<Map>(LocalStorage.workspacesBox),
      isEmpty,
    );
  });

  test('registry reuses an existing root instead of duplicating it', () async {
    final root = WorkspaceRootRef(
      kind: WorkspaceRootKind.localPath,
      platform: WorkspacePlatform.windows,
      value: workspaceDirectory.path,
      displayPath: workspaceDirectory.path,
      capabilities: const {WorkspaceCapability.read},
    );
    final repository = _MemoryWorkspaceRepository();
    final fileSystem = _FixedWorkspaceFileSystem(root);
    final notifier = WorkspaceRegistryNotifier(
      repository: repository,
      fileSystem: fileSystem,
      autoLoad: false,
    );

    final first = await notifier.addRoot(root, name: 'First');
    final second = await notifier.addRoot(root, name: 'Second');

    expect(second.id, first.id);
    expect(notifier.state.workspaces, hasLength(1));
    expect(repository.values, hasLength(1));
  });

  test('structured logs redact secret fields and bound retained events',
      () async {
    const canary = 'WORKSPACE_SECRET_CANARY';
    final sink = InMemoryStructuredLogSink(capacity: 1);
    final logger = StructuredLogger(sink);
    await logger.record(
      StructuredLogEvent(
        code: 'DD-TEST-ONE',
        level: LogLevel.info,
        message: 'Authorization: Bearer $canary',
        fields: const {'api_key': canary, 'visible': 'ok'},
      ),
    );
    await logger.record(
      StructuredLogEvent(
        code: 'DD-TEST-TWO',
        level: LogLevel.info,
        message: 'second',
      ),
    );

    expect(sink.events, hasLength(1));
    expect(sink.events.single.code, 'DD-TEST-TWO');

    final redacted = StructuredLogEvent(
      code: 'DD-TEST-REDACT',
      level: LogLevel.warning,
      message: 'token=$canary',
      fields: const {'password': canary},
    ).toMap().toString();
    expect(redacted, isNot(contains(canary)));
    expect(redacted, contains(DataRedactor.replacement));
  });
}

class _MemoryWorkspaceRepository implements WorkspaceRepository {
  final Map<String, DeveloperWorkspace> values = {};

  @override
  Future<DeveloperWorkspace?> getById(String id) async => values[id];

  @override
  Future<List<DeveloperWorkspace>> list() async => values.values.toList();

  @override
  Future<void> removeFromRegistry(String id) async => values.remove(id);

  @override
  Future<void> save(DeveloperWorkspace workspace) async {
    values[workspace.id] = workspace;
  }
}

class _FixedWorkspaceFileSystem implements WorkspaceFileSystem {
  final WorkspaceRootRef root;

  const _FixedWorkspaceFileSystem(this.root);

  @override
  Future<WorkspaceHealthSummary> inspect(WorkspaceRootRef root) async {
    return WorkspaceHealthSummary(
      status: WorkspaceHealthStatus.healthy,
      rootAvailable: true,
      canRead: true,
      canWrite: true,
      notices: const [],
      checkedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> createFile(
    WorkspaceRootRef root,
    String relativePath,
    Uint8List bytes,
  ) async {}

  @override
  Future<List<WorkspaceFileEntry>> list(
    WorkspaceRootRef root, {
    String relativeDirectory = '',
    int maxEntries = 10000,
  }) async {
    return const [];
  }

  @override
  String normalizeRelativePath(String relativePath) => relativePath;

  @override
  Future<WorkspaceRootRef?> pickRoot() async => root;

  @override
  Future<Uint8List> readBytes(
    WorkspaceRootRef root,
    String relativePath, {
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    return Uint8List(0);
  }

  @override
  Future<WorkspaceRootRef> rootFromLocalPath(String path) async => root;

  @override
  Stream<WorkspaceFileChange> watch(WorkspaceRootRef root) {
    return const Stream.empty();
  }

  @override
  Future<void> writeTextAtomically(
    WorkspaceRootRef root,
    String relativePath,
    String content, {
    String? expectedFingerprint,
  }) async {}
}
