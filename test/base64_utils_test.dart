import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/base64_utils.dart';
import 'package:devdesk/core/errors/failure.dart';

void main() {
  group('Base64Utils', () {
    test('encodes and decodes correctly', () {
      const input = 'Hello, World!';
      final encoded = Base64Utils.encode(input);
      final decoded = Base64Utils.decode(encoded);
      expect(decoded, input);
    });
    test('throws on invalid Base64', () {
      expect(() => Base64Utils.decode('@@@'), throwsA(isA<Base64Failure>()));
    });

    test('unicode round trip', () {
      const input = 'Hello नमस्ते こんにちは';
      expect(Base64Utils.decode(Base64Utils.encode(input)), input);
    });
  });
}
