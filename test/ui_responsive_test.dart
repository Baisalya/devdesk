import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/core/widgets/app_empty_state.dart';
import 'package:devdesk/core/widgets/app_error_state.dart';
import 'package:devdesk/core/widgets/app_loading_state.dart';
import 'package:devdesk/features/api_tester/presentation/api_page.dart';
import 'package:devdesk/features/dashboard/presentation/dashboard_page.dart';
import 'package:devdesk/features/external_files/presentation/text_file_page.dart';
import 'package:devdesk/features/json_tools/presentation/json_page.dart';
import 'package:devdesk/features/jwt_decoder/presentation/jwt_page.dart';
import 'package:devdesk/features/markdown/presentation/markdown_page.dart';
import 'package:devdesk/features/regex_tester/presentation/regex_page.dart';
import 'package:devdesk/features/settings/presentation/settings_page.dart';
import 'package:devdesk/features/snippets/presentation/snippets_page.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_ui_responsive');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  testWidgets('Dashboard mobile and desktop layouts expose quick actions',
      (tester) async {
    await _pumpAtSize(
      tester,
      const Size(360, 800),
      const DashboardPage(),
    );
    expect(find.text('DevKit Offline'), findsOneWidget);
    expect(find.text('Open File'), findsOneWidget);

    await _pumpAtSize(
      tester,
      const Size(1366, 768),
      const DashboardPage(),
    );
    expect(find.text('All developer tools'), findsOneWidget);
    expect(find.text('API Request'), findsOneWidget);
  });

  testWidgets('Markdown mobile toggle and desktop split render',
      (tester) async {
    await _pumpAtSize(tester, const Size(360, 800), const MarkdownPage());
    expect(find.text('Edit'), findsWidgets);
    expect(find.text('Preview'), findsWidgets);

    await _pumpAtSize(tester, const Size(1366, 768), const MarkdownPage());
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Rendered document'), findsOneWidget);
  });

  testWidgets('JSON mobile stacked and desktop split render', (tester) async {
    await _pumpAtSize(tester, const Size(360, 800), const JsonPage());
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Input'), findsOneWidget);

    await _pumpAtSize(tester, const Size(1366, 768), const JsonPage());
    expect(find.text('Result'), findsOneWidget);
  });

  testWidgets('API tester mobile and desktop panels render', (tester) async {
    await _pumpAtSize(tester, const Size(360, 800), const ApiPage());
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Params'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);

    await _pumpAtSize(tester, const Size(1366, 768), const ApiPage());
    expect(find.text('Response will appear here'), findsOneWidget);
  });

  testWidgets('JWT decoder output cards render', (tester) async {
    await _pumpAtSize(tester, const Size(800, 1280), const JwtPage());
    const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE4OTM0NTYwMDB9.signature';
    await tester.enterText(find.byType(TextField).first, token);
    await tester.tap(find.text('Decode'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Claims timeline'), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Payload'), findsOneWidget);
  });

  testWidgets('Regex match count UI renders', (tester) async {
    await _pumpAtSize(tester, const Size(800, 1280), const RegexPage());
    await tester.enterText(
        find.widgetWithText(TextField, 'Regex Pattern'), 'a');
    await tester.enterText(
        find.widgetWithText(TextField, 'Sample Text'), 'a b a');
    await tester.tap(find.text('Test'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Matches: 2'), findsOneWidget);
  });

  testWidgets('Snippets empty state renders', (tester) async {
    await _pumpAtSize(tester, const Size(360, 800), const SnippetsPage());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No snippets yet'), findsOneWidget);
  });

  testWidgets('Settings grouped sections render', (tester) async {
    await _pumpAtSize(tester, const Size(800, 1280), const SettingsPage());
    expect(find.text('Appearance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Data backup'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Data backup'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Plans'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('Purchases disabled'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Privacy & security'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Privacy & security'), findsOneWidget);
  });

  testWidgets('External file metadata header renders', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(1366, 768),
      TextFilePage(
        document: ExternalFileDocument(
          name: 'notes.env',
          sizeBytes: 12,
          content: 'TOKEN=local',
          kind: DevFileKind.text,
        ),
      ),
    );
    expect(find.text('notes.env'), findsWidgets);
    expect(find.text('Source'), findsOneWidget);
    expect(find.textContaining('secrets'), findsOneWidget);
  });

  testWidgets('Shared empty error and loading states render', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(360, 800),
      const Scaffold(
        body: Column(
          children: [
            Expanded(
              child: AppEmptyState(
                icon: Icons.inbox,
                title: 'Empty',
                message: 'Nothing here.',
              ),
            ),
            AppErrorState(message: 'Something failed'),
            Expanded(child: AppLoadingState(label: 'Loading data...')),
          ],
        ),
      ),
    );
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Something failed'), findsOneWidget);
    expect(find.text('Loading data...'), findsOneWidget);
  });

  testWidgets('Key pages do not overflow at required viewport sizes',
      (tester) async {
    final sizes = [
      const Size(360, 800),
      const Size(800, 1280),
      const Size(1366, 768),
      const Size(1920, 1080),
    ];
    final pages = <Widget>[
      const DashboardPage(),
      const MarkdownPage(),
      const JsonPage(),
      const ApiPage(),
    ];
    for (final size in sizes) {
      for (final page in pages) {
        await _pumpAtSize(tester, size, page);
      }
    }
  });
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  await _pumpRaw(
    tester,
    size,
    ProviderScope(child: MaterialApp(home: child)),
  );
}

Future<void> _pumpRaw(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(child);
  await tester.pump(const Duration(milliseconds: 120));
}
