import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/core/files/external_file.dart';
import 'package:devdesk/core/storage/backup_utils.dart';
import 'package:devdesk/core/storage/local_storage.dart';
import 'package:devdesk/features/settings/presentation/settings_page.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('devdesk_backup_widget');
    LocalStorage.initializeForTest(dir.path);
  });

  setUp(() async {
    await LocalStorage.clearAll();
  });

  testWidgets('Backup import preview appears before applying data',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SettingsPage(
            initialDocument: ExternalFileDocument(
              name: 'devdesk-backup.json',
              sizeBytes: 1,
              kind: DevFileKind.backup,
              content:
                  '{"type":"${BackupUtils.type}","boxes":{"markdown_files":{"README.md":"# Hi"},"snippets":{},"api_history":{},"api_environments":{},"settings":{}}}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Backup import preview'), findsOneWidget);
    expect(find.text('Markdown files: 1'), findsOneWidget);
  });
}
