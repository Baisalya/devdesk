import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:devdesk/features/api_tester/presentation/api_page.dart';
import 'package:devdesk/features/api_tester/provider/api_provider.dart';
import 'package:devdesk/core/storage/local_storage.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_api_test');
    LocalStorage.initializeForTest(dir.path);
  });

  testWidgets('API tester validates empty URL', (WidgetTester tester) async {
    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: ApiPage())));
    // Tap Send
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    // Expect SnackBar with message containing 'URL'
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('API tester shows mocked response UI',
      (WidgetTester tester) async {
    final client = MockClient((request) async {
      return http.Response('{"ok":true}', 200, headers: {
        'content-type': 'application/json',
      });
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: ApiPage()),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'https://api.example.com',
    );
    await tester.tap(find.text('Send'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Status 200'), findsOneWidget);
    expect(find.textContaining('"ok": true'), findsOneWidget);
  });
}
