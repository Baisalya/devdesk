import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/api_tester/models/api_request.dart';
import 'package:devdesk/features/api_tester/provider/api_workspace_storage.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_api_workspace');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  test('legacy API history is copied into a workspace and preserved', () async {
    final legacy = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
    await legacy.add(
      ApiRequest(
        method: 'GET',
        url: 'https://api.example.com/users',
        headers: {'Accept': 'application/json'},
      ).toMap(),
    );

    final workspaces = await ApiWorkspaceStorage.loadWorkspaces();

    expect(workspaces.single.name, 'Legacy API History');
    expect(workspaces.single.requestCount, 1);
    expect(legacy.length, 1);
  });
}
