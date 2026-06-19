import 'dart:convert';

import '../errors/failure.dart';

/// Utilities for Base64 encoding and decoding.
class Base64Utils {
  /// Encodes [input] into a Base64 string. Accepts any UTF‑8 string.
  static String encode(String input) {
    final bytes = utf8.encode(input);
    return base64Encode(bytes);
  }

  /// Decodes a Base64 string. Throws [Base64Failure] if the input is not
  /// valid Base64 or cannot be decoded as UTF‑8.
  static String decode(String input) {
    try {
      final decoded = base64Decode(input);
      return utf8.decode(decoded);
    } on FormatException {
      throw Base64Failure('Invalid Base64 string');
    } catch (e) {
      throw Base64Failure('Failed to decode Base64');
    }
  }
}
