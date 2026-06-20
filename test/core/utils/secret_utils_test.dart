import 'package:flutter_test/flutter_test.dart';
import 'package:devdesk/core/utils/secret_utils.dart';

void main() {
  group('SecretUtils Tests', () {
    test('Detects secrets by keyword', () {
      expect(SecretUtils.containsSecret('my API_KEY is 123'), isTrue);
      expect(SecretUtils.containsSecret('nothing here'), isFalse);
    });

    test('Detects secrets by pattern', () {
      expect(SecretUtils.containsSecret('token: "abcdef12345678"'), isTrue);
      expect(SecretUtils.containsSecret('password=supersecret'), isTrue);
    });

    test('Detects sensitive files', () {
      expect(SecretUtils.isSensitiveFile('.env'), isTrue);
      expect(SecretUtils.isSensitiveFile('server.key'), isTrue);
      expect(SecretUtils.isSensitiveFile('readme.txt'), isFalse);
    });

    test('Masks secrets in text', () {
      final input = 'api_key: "my-secret-key-123"';
      final masked = SecretUtils.maskSecrets(input);
      expect(masked, contains('api_key: "********"'));
    });
  });
}
