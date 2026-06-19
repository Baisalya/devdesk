import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/jwt_utils.dart';
import 'package:devdesk/core/errors/failure.dart';

void main() {
  group('JwtUtils', () {
    test('decodes valid token', () {
      // Header: {"alg":"HS256","typ":"JWT"}
      // Payload: {"sub":"1234567890","name":"John Doe","iat":1516239022,"exp":1893456000}
      const token =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE4OTM0NTYwMDB9.signature';
      final result = JwtUtils.decode(token);
      expect(result['header']['alg'], 'HS256');
      expect(result['payload']['name'], 'John Doe');
      expect(result['expiry'], isNotNull);
    });
    test('throws on invalid token', () {
      expect(() => JwtUtils.decode('invalid'), throwsA(isA<JwtFailure>()));
    });

    test('detects expired token', () {
      final token = _token({
        'alg': 'none'
      }, {
        'sub': '1',
        'exp': 946684800,
      });

      final result = JwtUtils.decode(token);

      expect(result['isExpired'], isTrue);
    });

    test('handles token with no exp', () {
      final token = _token({'alg': 'none'}, {'sub': '1'});

      final result = JwtUtils.decode(token);

      expect(result['expiry'], isNull);
      expect(result['isExpired'], isFalse);
    });

    test('throws on malformed Base64URL', () {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': '1'})))
          .replaceAll('=', '');

      expect(
        () => JwtUtils.decode('###.$payload.signature'),
        throwsA(isA<JwtFailure>()),
      );
    });
  });
}

String _token(Map<String, dynamic> header, Map<String, dynamic> payload) {
  String encodePart(Map<String, dynamic> part) {
    return base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  }

  return '${encodePart(header)}.${encodePart(payload)}.signature';
}
