import '../errors/failure.dart';

/// Utilities for encoding and decoding URL components.
class UrlUtils {
  /// Encodes [input] so it is safe to use as a URL component. Uses
  /// `Uri.encodeComponent` under the hood.
  static String encode(String input) {
    try {
      return Uri.encodeComponent(input);
    } catch (e) {
      throw UrlFailure('Failed to encode URL');
    }
  }

  /// Decodes an encoded URL component. Throws [UrlFailure] if the input
  /// cannot be decoded.
  static String decode(String input) {
    try {
      return Uri.decodeComponent(input);
    } catch (e) {
      throw UrlFailure('Failed to decode URL');
    }
  }
}
