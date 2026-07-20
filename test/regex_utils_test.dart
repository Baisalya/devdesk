import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/regex_utils.dart';
import 'package:devdesk/core/errors/failure.dart';

void main() {
  group('RegexUtils', () {
    test('matches occurrences', () {
      final matches = RegexUtils.testRegex('a', 'banana');
      expect(matches.length, 3);
    });
    test('multiLine and case sensitivity', () {
      final matches = RegexUtils.testRegex('^h', 'Hello\nhow',
          multiLine: true, caseSensitive: false);
      expect(matches.length, 2);
    });
    test('invalid regex throws', () {
      expect(() => RegexUtils.testRegex('[', 'text'),
          throwsA(isA<RegexFailure>()));
    });

    test('empty pattern returns no matches', () {
      expect(RegexUtils.testRegex('', 'text'), isEmpty);
    });

    test('rejects common catastrophic nested quantifier shape', () {
      expect(
        () => RegexUtils.testRegex(
          r'(a+)+$',
          "${List.filled(10000, 'a').join()}!",
        ),
        throwsA(
          isA<RegexFailure>().having(
            (failure) => failure.message,
            'message',
            contains('backtracking risk'),
          ),
        ),
      );
    });

    test('rejects oversized input before regex evaluation', () {
      expect(
        () => RegexUtils.testRegex(
          'a',
          List.filled(RegexUtils.maxInputBytes + 1, 'a').join(),
        ),
        throwsA(isA<RegexFailure>()),
      );
    });
  });
}
