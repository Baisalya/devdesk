import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/app/command_registry.dart';
import 'package:devdesk/core/widgets/safe_markdown_image.dart';
import 'package:devdesk/features/json_tools/presentation/json_page.dart';

void main() {
  testWidgets('JSON tree exposes readable object and value semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JsonTreeView(
            data: {
              'enabled': true,
              'nested': {'count': 2},
            },
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('enabled: true'), findsOneWidget);
    expect(
      find.bySemanticsLabel('nested, expandable object with 1 items'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('blocked Markdown images have an explicit semantic alternative',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildSafeMarkdownImage(
            Uri.parse('https://tracker.example/pixel.png'),
            null,
            'Architecture diagram',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Architecture diagram. Remote image blocked.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Ctrl+N and Ctrl+L invoke registered navigation commands',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: devDeskNavigatorKey,
        shortcuts: devDeskShortcuts,
        actions: devDeskActions,
        initialRoute: '/dashboard',
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Dashboard route')),
          '/markdown': (_) => const Scaffold(body: Text('Markdown route')),
        },
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Markdown route'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard route'), findsOneWidget);
  });
}
