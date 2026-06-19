import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/json_utils.dart';
import 'package:devdesk/core/errors/failure.dart';

void main() {
  group('JsonUtils', () {
    test('parses valid JSON', () {
      final json = '{"name":"Alice","age":30}';
      final result = JsonUtils.parseJson(json);
      expect(result, isA<Map>());
      expect(result['name'], 'Alice');
      expect(result['age'], 30);
    });
    test('throws on invalid JSON', () {
      const invalid = '{name: Alice}';
      expect(() => JsonUtils.parseJson(invalid), throwsA(isA<JsonFailure>()));
    });
    test('invalid JSON includes line and column', () {
      const invalid = '{\n  "name": \n}';
      expect(
        () => JsonUtils.parseJson(invalid),
        throwsA(
          isA<JsonFailure>().having(
            (failure) => failure.message,
            'message',
            contains('line'),
          ),
        ),
      );
    });
    test('pretty prints JSON', () {
      final obj = {'a': 1, 'b': true};
      final pretty = JsonUtils.prettyPrint(obj);
      expect(pretty.contains('\n'), isTrue);
      expect(pretty.contains('  '), isTrue);
    });
    test('minifies JSON', () {
      final obj = {'a': 1, 'b': true};
      final minified = JsonUtils.minify(obj);
      expect(minified.contains(' '), isFalse);
      expect(minified.contains('\n'), isFalse);
    });
    test('large JSON formats without crashing', () {
      final items = List.generate(1000, (index) => {'id': index});
      final pretty = JsonUtils.prettyPrint({'items': items});
      expect(pretty, contains('"items"'));
    });
  });
}
