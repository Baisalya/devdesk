import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/provider/api_workspace_provider.dart';

class _ControlledClient extends http.BaseClient {
  final StreamController<List<int>> controller = StreamController<List<int>>();
  final String body;
  bool closed = false;
  int sendCount = 0;

  _ControlledClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCount++;
    return http.StreamedResponse(
      controller.stream,
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> complete() async {
    if (!controller.isClosed) {
      controller.add(body.codeUnits);
      // A request cancelled before the response stream is subscribed has no
      // listener. StreamController.close() intentionally waits for a listener
      // in that case, so do not make test cleanup depend on it.
      unawaited(controller.close());
    }
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

ApiWorkspaceState _initialState() {
  final request = ApiRequestItem(
    id: 'request-1',
    name: 'Lifecycle request',
    method: 'GET',
    url: 'https://example.test/data',
  );
  final collection = ApiCollection(
    id: 'collection-1',
    name: 'Collection',
    requests: [request],
  );
  final workspace = ApiWorkspace(
    id: 'workspace-1',
    name: 'Workspace',
    collections: [collection],
  );
  return ApiWorkspaceState(
    workspaces: [workspace],
    activeWorkspaceId: workspace.id,
    selectedCollectionId: collection.id,
    selectedRequestId: request.id,
  );
}

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('devdesk_api_lifecycle_');
    LocalStorage.initializeForTest(directory.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  tearDownAll(() async {
    await LocalStorage.closeAll();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('duplicate Send is ignored while the first operation is running',
      () async {
    final client = _ControlledClient('{"source":"first"}');
    var factoryCalls = 0;
    final notifier = ApiWorkspaceNotifier(
      autoLoad: false,
      initialState: _initialState(),
      clientFactory: () {
        factoryCalls++;
        return client;
      },
    );

    final first = notifier.sendSelectedRequest();
    expect(notifier.state.sending, isTrue);
    await notifier.sendSelectedRequest();
    expect(factoryCalls, 1);
    expect(client.sendCount, 1);

    await client.complete();
    await first;
    expect(notifier.state.response?.body, contains('first'));
    notifier.dispose();
  });

  test('cancelled older response cannot overwrite a newer operation', () async {
    final firstClient = _ControlledClient('{"source":"old"}');
    final secondClient = _ControlledClient('{"source":"new"}');
    final clients = [firstClient, secondClient];
    final notifier = ApiWorkspaceNotifier(
      autoLoad: false,
      initialState: _initialState(),
      clientFactory: () => clients.removeAt(0),
    );

    final first = notifier.sendSelectedRequest();
    notifier.cancelRequest();
    final second = notifier.sendSelectedRequest();
    await secondClient.complete();
    await second;
    await first;
    await firstClient.complete();

    expect(notifier.state.response?.body, contains('new'));
    expect(notifier.state.response?.body, isNot(contains('old')));
    expect(firstClient.closed, isTrue);
    notifier.dispose();
  });

  test('provider disposal cancels the active client and suppresses late state',
      () async {
    final client = _ControlledClient('{"late":true}');
    final notifier = ApiWorkspaceNotifier(
      autoLoad: false,
      initialState: _initialState(),
      clientFactory: () => client,
    );

    final operation = notifier.sendSelectedRequest();
    notifier.dispose();
    expect(client.closed, isTrue);
    await client.complete();
    await operation;
  });
}
