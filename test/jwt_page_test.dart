import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devdesk/features/jwt_decoder/presentation/jwt_page.dart';

void main() {
  testWidgets('JWT decoder shows decoded name', (WidgetTester tester) async {
    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: JwtPage())));
    // Sample token (header and payload from jwt_utils_test)
    const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE4OTM0NTYwMDB9.signature';
    // Enter token
    await tester.enterText(find.byType(TextField).first, token);
    await tester.pumpAndSettle();
    // Tap Decode
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('John Doe'), findsWidgets);
  });
}
