import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/api_tester/presentation/api_page.dart';
import 'package:devdesk/features/api_tester/presentation/api_workspaces_page.dart';
import 'package:devdesk/features/api_tester/provider/api_workspace_provider.dart';
import 'package:devdesk/features/base64_tool/presentation/base64_page.dart';
import 'package:devdesk/features/dashboard/presentation/dashboard_page.dart';
import 'package:devdesk/features/dashboard/presentation/favourites_page.dart';
import 'package:devdesk/features/dashboard/presentation/recent_page.dart';
import 'package:devdesk/features/diff_checker/presentation/diff_page.dart';
import 'package:devdesk/features/external_files/presentation/text_file_page.dart';
import 'package:devdesk/features/json_tools/presentation/json_page.dart';
import 'package:devdesk/features/jwt_decoder/presentation/jwt_page.dart';
import 'package:devdesk/features/markdown/presentation/markdown_page.dart';
import 'package:devdesk/features/markdown/vault/presentation/vault_page.dart';
import 'package:devdesk/features/readme_generator/presentation/readme_page.dart';
import 'package:devdesk/features/regex_tester/presentation/regex_page.dart';
import 'package:devdesk/features/settings/presentation/settings_page.dart';
import 'package:devdesk/features/snippets/presentation/snippets_page.dart';
import 'package:devdesk/features/timestamp_tool/presentation/timestamp_page.dart';
import 'package:devdesk/features/url_tool/presentation/url_page.dart';
import 'package:devdesk/features/uuid_tool/presentation/uuid_page.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'devdesk_responsive_matrix',
    );
    LocalStorage.initializeForTest(storageDirectory.path);
    await LocalStorage.clearAll();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    // Storage-backed providers finish their in-flight reads after their
    // ProviderScopes are disposed. Let those futures drain before closing Hive.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await LocalStorage.closeAll();
    if (storageDirectory.existsSync()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  final pages = <String, Widget Function()>{
    'dashboard': DashboardPage.new,
    'favourites': FavouritesPage.new,
    'recent': RecentPage.new,
    'vault': VaultPage.new,
    'markdown': MarkdownPage.new,
    'readme': ReadmeGeneratorPage.new,
    'json': JsonPage.new,
    'api-workspaces': ApiWorkspacesPage.new,
    'quick-api': ApiPage.new,
    'jwt': JwtPage.new,
    'regex': RegexPage.new,
    'base64': Base64Page.new,
    'url': UrlPage.new,
    'timestamp': TimestampPage.new,
    'uuid': UuidPage.new,
    'diff': DiffPage.new,
    'snippets': SnippetsPage.new,
    'settings': SettingsPage.new,
    'external-text': () => TextFilePage(
          document: ExternalFileDocument(
            name: 'responsive-audit.txt',
            sizeBytes: 5,
            content: 'audit',
            kind: DevFileKind.text,
          ),
        ),
  };

  final viewports = <String, Size>{
    'graceful-minimum': const Size(280, 480),
    'compact-phone': const Size(320, 568),
    'short-landscape': const Size(568, 320),
    'freeform': const Size(500, 400),
    'compact-desktop': const Size(900, 600),
  };

  for (final viewport in viewports.entries) {
    for (final page in pages.entries) {
      testWidgets('${page.key} fits ${viewport.key}', (tester) async {
        await _pumpPage(
          tester,
          size: viewport.value,
          page: page.value(),
        );

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason:
              '${page.key} must fit ${viewport.value}\n${_describe(exception)}',
        );
      });
    }
  }

  for (final page in pages.entries) {
    testWidgets('${page.key} fits compact phone at 200% text', (tester) async {
      await _pumpPage(
        tester,
        size: const Size(320, 568),
        page: page.value(),
        textScale: 2,
      );

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason:
            '${page.key} must support large accessibility text\n${_describe(exception)}',
      );
    });
  }
}

String _describe(Object? exception) {
  if (exception is FlutterError) return exception.toStringDeep();
  return exception?.toString() ?? '';
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Size size,
  required Widget page,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiWorkspaceProvider.overrideWith((ref) {
          return ApiWorkspaceNotifier(
            autoLoad: false,
            initialState: const ApiWorkspaceState(),
          );
        }),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 180));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}
