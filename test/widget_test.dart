import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/app/app.dart';

void main() {
  testWidgets('DevDesk app loads dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('DevDesk'), findsOneWidget);
    expect(find.text('Markdown Editor'), findsOneWidget);
  });
}
