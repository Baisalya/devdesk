import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/api_tester/models/api_response.dart';
import 'package:devdesk/features/api_tester/models/api_request.dart';

void main() {
  group('ApiRequest', () {
    test('serialization round trip', () {
      final request = ApiRequest(
        method: 'POST',
        url: 'https://api.example.com',
        headers: {'Content-Type': 'application/json'},
        queryParams: {'q': 'flutter'},
        body: '{"data":1}',
      );
      final map = request.toMap();
      final restored = ApiRequest.fromMap(map);
      expect(restored.method, request.method);
      expect(restored.url, request.url);
      expect(restored.headers, request.headers);
      expect(restored.queryParams, request.queryParams);
      expect(restored.body, request.body);
    });

    test('removes sensitive headers for history', () {
      final request = ApiRequest(
        method: 'GET',
        url: 'https://api.example.com',
        headers: {
          'Authorization': 'Bearer secret',
          'X-Api-Key': 'secret',
          'Accept': 'application/json',
        },
      );

      final sanitized = request.withoutSensitiveHeaders();

      expect(sanitized.headers, {'Accept': 'application/json'});
    });
  });

  group('ApiResponse', () {
    test('serialization round trip', () {
      final response = ApiResponse(
        method: 'GET',
        url: 'https://api.example.com',
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true}',
        duration: const Duration(milliseconds: 42),
      );

      final restored = ApiResponse.fromMap(response.toMap());

      expect(restored.statusCode, response.statusCode);
      expect(restored.headers, response.headers);
      expect(restored.body, response.body);
      expect(restored.duration, response.duration);
    });
  });
}
