import 'dart:convert';

import '../errors/failure.dart';

/// Utilities for decoding JSON Web Tokens (JWT) without verifying the
/// signature. The token is split by '.' into header, payload and
/// signature. The header and payload are Base64URL‑decoded into JSON.
class JwtUtils {
  /// Decodes the header and payload of a JWT. Returns a map containing
  /// `header`, `payload`, readable time claims, and a signature warning.
  /// Throws [JwtFailure] if the token is malformed.
  static Map<String, dynamic> decode(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw JwtFailure('Invalid JWT: requires at least header and payload');
    }
    try {
      final header = _decodeBase64Url(parts[0]);
      final payload = _decodeBase64Url(parts[1]);
      final Map<String, dynamic> headerMap = jsonDecode(header);
      final Map<String, dynamic> payloadMap = jsonDecode(payload);
      final expiry = _dateFromClaim(payloadMap['exp']);
      final issuedAt = _dateFromClaim(payloadMap['iat']);
      final notBefore = _dateFromClaim(payloadMap['nbf']);
      return {
        'header': headerMap,
        'payload': payloadMap,
        'expiry': expiry,
        'issuedAt': issuedAt,
        'notBefore': notBefore,
        'isExpired': expiry != null && expiry.isBefore(DateTime.now().toUtc()),
        'signatureVerified': false,
      };
    } on JwtFailure {
      rethrow;
    } on FormatException {
      throw JwtFailure('Invalid JWT JSON');
    } catch (e) {
      throw JwtFailure('Invalid JWT');
    }
  }

  static String _decodeBase64Url(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw JwtFailure('Invalid Base64URL string');
    }
    try {
      return utf8.decode(base64Url.decode(output));
    } on FormatException {
      throw JwtFailure('Invalid Base64URL string');
    }
  }

  static DateTime? _dateFromClaim(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).toInt(),
        isUtc: true,
      );
    }
    return null;
  }
}
