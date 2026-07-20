import 'dart:convert';

import '../errors/failure.dart';

/// Bounded JSON parsing/formatting utilities for untrusted developer input.
class JsonUtils {
  static const int maxInputBytes = 5 * 1024 * 1024;
  static const int maxDepth = 128;
  static const int maxNodes = 100000;

  static dynamic parseJson(String input) {
    _guardInput(input);
    try {
      final decoded = jsonDecode(input);
      _validateStructure(decoded);
      return decoded;
    } on JsonFailure {
      rethrow;
    } on FormatException catch (error) {
      throw JsonFailure(_formatError(input, error));
    } catch (_) {
      throw JsonFailure('Invalid JSON.');
    }
  }

  static String prettyPrint(dynamic json) {
    try {
      final data = json is String ? parseJson(json) : json;
      _validateStructure(data);
      return const JsonEncoder.withIndent('  ').convert(data);
    } on JsonFailure {
      rethrow;
    } on FormatException catch (error) {
      final source = json is String ? json : '';
      throw JsonFailure(_formatError(source, error));
    } catch (_) {
      throw JsonFailure('Invalid JSON.');
    }
  }

  static String minify(dynamic json) {
    try {
      final data = json is String ? parseJson(json) : json;
      _validateStructure(data);
      return jsonEncode(data);
    } on JsonFailure {
      rethrow;
    } on FormatException catch (error) {
      final source = json is String ? json : '';
      throw JsonFailure(_formatError(source, error));
    } catch (_) {
      throw JsonFailure('Invalid JSON.');
    }
  }

  static void _guardInput(String input) {
    if (utf8.encode(input).length > maxInputBytes) {
      throw JsonFailure('JSON input is larger than the 5 MB safety limit.');
    }
  }

  static void _validateStructure(dynamic root) {
    var nodes = 0;
    final stack = <({dynamic value, int depth})>[(value: root, depth: 0)];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      nodes++;
      if (nodes > maxNodes) {
        throw JsonFailure('JSON contains too many values to process safely.');
      }
      if (current.depth > maxDepth) {
        throw JsonFailure('JSON is nested too deeply to process safely.');
      }
      final value = current.value;
      if (value is Map) {
        for (final entry in value.entries) {
          stack.add((value: entry.value, depth: current.depth + 1));
        }
      } else if (value is Iterable) {
        for (final item in value) {
          stack.add((value: item, depth: current.depth + 1));
        }
      }
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
