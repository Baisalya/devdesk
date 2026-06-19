import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/features/api_tester/models/api_environment.dart';
import 'package:devdesk/features/api_tester/models/api_variable.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/presentation/api_workspaces_page.dart';
import 'package:devdesk/features/api_tester/provider/api_workspace_provider.dart';
import 'package:devdesk/features/api_tester/utils/api_workspace_utils.dart';

void main() {
  testWidgets('workspace list empty state and create dialog render',
      (tester) async {
    await _pumpAtSize(
      tester,
      const Size(800, 1280),
      const ApiWorkspacesPage(),
      overrides: [_workspaceOverride(const ApiWorkspaceState())],
    );

    expect(
      find.text('Create your first API workspace', skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Create workspace').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create API workspace'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Windows wide workspace detail shows 3-pane collections layout',
      (tester) async {
    final workspace = _sampleWorkspace();
    await _pumpAtSize(
      tester,
      const Size(1366, 768),
      const ApiWorkspacesPage(),
      overrides: [_workspaceOverride(_detailState(workspace))],
    );

    expect(find.text('Collections', skipOffstage: false), findsWidgets);
    expect(find.text('Request name'), findsOneWidget);
    expect(find.text('Response will appear here'), findsOneWidget);
    expect(find.text('GET', skipOffstage: false), findsWidgets);
    expect(
      find.text('Unresolved variable warning', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('Android narrow workspace detail uses tab layout',
      (tester) async {
    final workspace = _sampleWorkspace();
    await _pumpAtSize(
      tester,
      const Size(360, 800),
      const ApiWorkspacesPage(),
      overrides: [_workspaceOverride(_detailState(workspace))],
    );

    expect(find.text('Collections', skipOffstage: false), findsWidgets);
    expect(find.text('Variables', skipOffstage: false), findsWidgets);
    expect(find.text('Runner', skipOffstage: false), findsWidgets);
  });

  testWidgets('import preview warns about secrets', (tester) async {
    final workspace = _sampleWorkspace().copyWith(
      variables: const [
        ApiVariable(key: 'token', value: 'secret', isSecret: true),
      ],
    );
    final content = const JsonEncoder.withIndent('  ').convert(
      ApiWorkspaceImportExport.exportWorkspace(workspace, includeSecrets: true),
    );

    await _pumpAtSize(
      tester,
      const Size(800, 1280),
      ApiWorkspacesPage(
        initialDocument: ExternalFileDocument(
          name: 'workspace.json',
          sizeBytes: utf8.encode(content).length,
          content: content,
          kind: DevFileKind.apiCollection,
        ),
      ),
      overrides: [_workspaceOverride(const ApiWorkspaceState())],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Import API workspace'), findsOneWidget);
    expect(find.text('Import without secrets'), findsOneWidget);
    expect(find.text('Import with secrets'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('workspace page does not overflow at required viewport sizes',
      (tester) async {
    final workspace = _sampleWorkspace();
    for (final size in const [
      Size(360, 800),
      Size(800, 1280),
      Size(1366, 768),
      Size(1920, 1080),
    ]) {
      await _pumpAtSize(
        tester,
        size,
        const ApiWorkspacesPage(),
        overrides: [
          _workspaceOverride(
            ApiWorkspaceState(workspaces: [workspace]),
          ),
        ],
      );
      expect(find.text('My Shopping App'), findsWidgets);
    }
  });
}

ApiWorkspace _sampleWorkspace() {
  return ApiWorkspace(
    id: 'workspace-sample',
    name: 'My Shopping App',
    description: 'Shopping APIs',
    environments: [
      ApiEnvironment(
        id: 'local',
        name: 'Local',
        baseUrl: 'http://10.0.2.2:3000',
      ),
    ],
    activeEnvironmentId: 'local',
    collections: [
      ApiCollection(
        id: 'collection-products',
        name: 'Products',
        folders: [
          ApiFolder(
            id: 'folder-products',
            name: 'Products',
            requests: [
              ApiRequestItem(
                id: 'request-products',
                name: 'Get Products',
                method: 'GET',
                url: '{{baseUrl}}/products/{{userId}}',
                assertions: const [
                  ApiAssertion(
                    id: 'assert-status',
                    name: 'status == 200',
                    type: ApiAssertionType.statusCodeEquals,
                    expected: '200',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Override _workspaceOverride(ApiWorkspaceState state) {
  return apiWorkspaceProvider.overrideWith(
    (ref) => ApiWorkspaceNotifier(autoLoad: false, initialState: state),
  );
}

ApiWorkspaceState _detailState(ApiWorkspace workspace) {
  final collection = workspace.collections.first;
  final folder = collection.folders.first;
  final request = folder.requests.first;
  return ApiWorkspaceState(
    workspaces: [workspace],
    activeWorkspaceId: workspace.id,
    selectedCollectionId: collection.id,
    selectedFolderId: folder.id,
    selectedRequestId: request.id,
    section: ApiWorkspaceSection.collections,
  );
}
