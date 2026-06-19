import '../errors/failure.dart';

/// Utilities for converting between Unix timestamps and DateTime.
class TimestampUtils {
  /// Converts a Unix timestamp in seconds (or milliseconds) to a [DateTime].
  /// Throws [TimestampFailure] if the input cannot be parsed.
  static DateTime fromUnix(String input) {
    try {
      var value = num.parse(input);
      // If it's in milliseconds (13 digits), convert to seconds.
      if (input.length >= 13) {
        value = value ~/ 1000;
      }
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt(),
          isUtc: false);
    } catch (e) {
      throw TimestampFailure('Invalid timestamp');
    }
  }

  /// Converts a [DateTime] to a Unix timestamp in seconds. Returns as
  /// String.
  static String toUnix(DateTime date) {
    return (date.millisecondsSinceEpoch ~/ 1000).toString();
  }

  /// Converts a [DateTime] to a Unix timestamp in milliseconds. Returns as
  /// String.
  static String toUnixMillis(DateTime date) {
    return date.millisecondsSinceEpoch.toString();
  }
}
