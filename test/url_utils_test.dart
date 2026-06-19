import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/core/utils/url_utils.dart';

void main() {
  group('UrlUtils', () {
    test('encodes and decodes correctly', () {
      const input = 'Hello World!';
      final encoded = UrlUtils.encode(input);
      final decoded = UrlUtils.decode(encoded);
      expect(decoded, input);
    });
    test('encoding produces %20 for space', () {
      const input = ' ';
      final encoded = UrlUtils.encode(input);
      expect(encoded.contains('%20'), isTrue);
    });

    test('decodes URL with query safely', () {
      const input = 'https%3A%2F%2Fexample.com%2Fsearch%3Fq%3Ddev%2520desk';
      expect(
        UrlUtils.decode(input),
        'https://example.com/search?q=dev%20desk',
      );
    });

    test('invalid percent escape throws UrlFailure', () {
      expect(() => UrlUtils.decode('%E0%A4%A'), throwsA(isA<UrlFailure>()));
    });
  });
}
