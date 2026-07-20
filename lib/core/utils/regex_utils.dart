import 'dart:convert';

import '../errors/failure.dart';

/// Bounded regular-expression evaluation. Dart's backtracking engine cannot be
/// forcibly interrupted in the same isolate, so patterns with common
/// catastrophic shapes are rejected before evaluation.
class RegexUtils {
  static const int maxPatternLength = 2048;
  static const int maxInputBytes = 1024 * 1024;
  static const int maxMatches = 10000;

  static final RegExp _nestedQuantifier = RegExp(
    r'\((?:[^()\\]|\\.)*[+*](?:[^()\\]|\\.)*\)\s*(?:[+*]|\{\d*,?\d*\})',
  );
  static final RegExp _ambiguousWildcard =
      RegExp(r'(?:\.\*|\.\+).*(?:\.\*|\.\+)');
  static final RegExp _backReference = RegExp(r'\\[1-9]');

  static List<Match> testRegex(
    String pattern,
    String input, {
    bool multiLine = false,
    bool caseSensitive = true,
  }) {
    if (pattern.isEmpty) return const [];
    if (pattern.length > maxPatternLength) {
      throw RegexFailure('Regex pattern is longer than the safe limit.');
    }
    final inputBytes = utf8.encode(input).length;
    if (inputBytes > maxInputBytes) {
      throw RegexFailure('Regex input is larger than the 1 MB safety limit.');
    }
    if (_looksCatastrophic(pattern, inputBytes)) {
      throw RegexFailure(
        'This pattern has a high backtracking risk. Simplify nested or overlapping quantifiers.',
      );
    }
    try {
      final regExp = RegExp(
        pattern,
        multiLine: multiLine,
        caseSensitive: caseSensitive,
      );
      final matches = regExp.allMatches(input).take(maxMatches + 1).toList();
      if (matches.length > maxMatches) {
        throw RegexFailure('Regex produced more than $maxMatches matches.');
      }
      return matches;
    } on RegexFailure {
      rethrow;
    } on FormatException catch (error) {
      throw RegexFailure('Invalid regex: ${error.message}');
    }
  }

  static bool _looksCatastrophic(String pattern, int inputBytes) {
    if (_nestedQuantifier.hasMatch(pattern)) return true;
    if (inputBytes > 64 * 1024 && _ambiguousWildcard.hasMatch(pattern)) {
      return true;
    }
    if (inputBytes > 64 * 1024 && _backReference.hasMatch(pattern)) {
      return true;
    }
    return false;
  }
}
