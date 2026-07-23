import 'package:devdesk/features/openapi/presentation/openapi_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(360, 640), Size(900, 700)]) {
    testWidgets('OpenAPI Studio fits ${size.width.toInt()}px viewport',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: OpenApiPage()),
        ),
      );
      await tester.pump();
      expect(find.text('OpenAPI Studio'), findsOneWidget);
      expect(find.text('Validate and inspect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
