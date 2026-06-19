import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/uuid_utils.dart';

void main() {
  group('UuidUtils', () {
    test('generates unique v4 UUIDs', () {
      final id1 = UuidUtils.generate();
      final id2 = UuidUtils.generate();
      expect(id1, isNot(equals(id2)));
      expect(
        id1,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
    test('generate many', () {
      final ids = UuidUtils.generateMany(5);
      expect(ids.length, 5);
      expect(ids.toSet().length, 5);
    });

    test('invalid count throws', () {
      expect(() => UuidUtils.generateMany(0), throwsArgumentError);
      expect(() => UuidUtils.generateMany(1001), throwsArgumentError);
    });
  });
}
