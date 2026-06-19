import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/readme_generator/presentation/readme_page.dart';

void main() {
  testWidgets('README generator validates required project name',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReadmeGeneratorPage()));

    await tester.ensureVisible(find.text('Generate README'));
    await tester.tap(find.text('Generate README'));
    await tester.pumpAndSettle();

    expect(find.text('Project name is required'), findsOneWidget);
  });

  testWidgets('generated README contains title features install and license',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReadmeGeneratorPage()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Project Name'),
      'DevDesk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Features (one per line)'),
      'Offline tools',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Installation'),
      'flutter pub get',
    );
    await tester.ensureVisible(find.text('Generate README'));
    await tester.tap(find.text('Generate README'));
    await tester.pumpAndSettle();

    expect(find.text('Output'), findsWidgets);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Save as Markdown'), findsOneWidget);
    expect(find.textContaining('# DevDesk'), findsOneWidget);
    expect(find.textContaining('## Features'), findsOneWidget);
    expect(find.textContaining('## Installation'), findsOneWidget);
    expect(find.textContaining('## License'), findsOneWidget);
  });
}
