import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/api_tester/presentation/api_page.dart';
import 'package:devdesk/features/api_tester/utils/api_collection_utils.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_api_widget');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  testWidgets('API collection import warns about sensitive headers',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ApiPage(
            initialDocument: ExternalFileDocument(
              name: 'collection.json',
              sizeBytes: 1,
              kind: DevFileKind.apiCollection,
              content:
                  '{"type":"${ApiCollectionUtils.type}","requests":[{"method":"GET","url":"https://api.example.com","headers":{"Authorization":"Bearer secret"},"queryParams":{}}]}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Import API collection'), findsOneWidget);
    expect(find.text('Import without secrets'), findsOneWidget);
    expect(find.text('Import with secrets'), findsOneWidget);
  });
}
