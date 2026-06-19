import '../errors/failure.dart';

/// Utilities for testing regular expressions against text.
class RegexUtils {
  /// Tests a regular expression against [input] and returns all matches. If
  /// the pattern is invalid, throws [RegexFailure]. Flags can be provided
  /// via the [multiLine] and [caseSensitive] parameters.
  static List<Match> testRegex(
    String pattern,
    String input, {
    bool multiLine = false,
    bool caseSensitive = true,
  }) {
    if (pattern.isEmpty) {
      return const [];
    }
    try {
      final regExp = RegExp(
        pattern,
        multiLine: multiLine,
        caseSensitive: caseSensitive,
      );
      return regExp.allMatches(input).toList();
    } on FormatException catch (e) {
      throw RegexFailure('Invalid regex: ${e.message}');
    }
  }
}
