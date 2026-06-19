import 'dart:convert';

import '../errors/failure.dart';

/// Utilities for parsing, formatting and validating JSON.
class JsonUtils {
  /// Parses and validates a JSON string. Returns the decoded object or
  /// throws [JsonFailure] if the input is invalid. The exception includes
  /// the error message from the parser.
  static dynamic parseJson(String input) {
    try {
      return jsonDecode(input);
    } on FormatException catch (e) {
      throw JsonFailure(_formatError(input, e));
    } catch (e) {
      throw JsonFailure('Invalid JSON');
    }
  }

  /// Pretty‑prints a JSON object with indentation. Accepts either a Dart
  /// object (Map/List) or a raw JSON string. Throws [JsonFailure] on error.
  static String prettyPrint(dynamic json) {
    try {
      final dynamic data;
      if (json is String) {
        data = jsonDecode(json);
      } else {
        data = json;
      }
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } on FormatException catch (e) {
      final source = json is String ? json : '';
      throw JsonFailure(_formatError(source, e));
    } catch (_) {
      throw JsonFailure('Invalid JSON');
    }
  }

  /// Minifies a JSON object by removing unnecessary whitespace. Accepts
  /// either a Dart object or a JSON string. Throws [JsonFailure] on error.
  static String minify(dynamic json) {
    try {
      final dynamic data;
      if (json is String) {
        data = jsonDecode(json);
      } else {
        data = json;
      }
      return jsonEncode(data);
    } on FormatException catch (e) {
      final source = json is String ? json : '';
      throw JsonFailure(_formatError(source, e));
    } catch (_) {
      throw JsonFailure('Invalid JSON');
    }
  }

  static String _formatError(String input, FormatException exception) {
    final offset = exception.offset;
    if (offset == null || input.isEmpty) {
      return 'Invalid JSON: ${exception.message}';
    }
    var line = 1;
    var column = 1;
    final safeOffset = offset.clamp(0, input.length).toInt();
    for (var i = 0; i < safeOffset; i++) {
      if (input.codeUnitAt(i) == 10) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return 'Invalid JSON at line $line, column $column: ${exception.message}';
  }
}
