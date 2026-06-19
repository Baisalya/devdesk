import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/core/utils/timestamp_utils.dart';

void main() {
  group('TimestampUtils', () {
    test('converts unix seconds to DateTime', () {
      final date =
          TimestampUtils.fromUnix('1609459200'); // 2021-01-01 00:00:00 UTC
      expect(date.year, 2021);
    });
    test('converts unix milliseconds to DateTime', () {
      final date = TimestampUtils.fromUnix('1609459200000');
      expect(date.year, 2021);
    });
    test('converts DateTime to unix', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1609459200000);
      final seconds = TimestampUtils.toUnix(date);
      expect(seconds, '1609459200');
      final millis = TimestampUtils.toUnixMillis(date);
      expect(millis, '1609459200000');
    });

    test('invalid input throws TimestampFailure', () {
      expect(
        () => TimestampUtils.fromUnix('not-a-number'),
        throwsA(isA<TimestampFailure>()),
      );
    });
  });
}
