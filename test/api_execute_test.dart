import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/api_tester/models/api_request.dart';
import 'package:devdesk/features/api_tester/provider/api_provider.dart';

void main() {
  test('GET request uses mocked client and returns response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://api.example.com/users?q=devdesk');
      return http.Response('{"ok":true}', 200, headers: {
        'content-type': 'application/json',
      });
    });

    final response = await executeApiRequest(
      request: ApiRequest(
        method: 'GET',
        url: 'https://api.example.com/users',
        queryParams: {'q': 'devdesk'},
      ),
      client: client,
      timeout: const Duration(seconds: 5),
    );

    expect(response.statusCode, 200);
    expect(response.body, '{"ok":true}');
  });

  test('POST JSON request sends request body', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(request.body, '{"name":"DevDesk"}');
      return http.Response('created', 201);
    });

    final response = await executeApiRequest(
      request: ApiRequest(
        method: 'POST',
        url: 'https://api.example.com/users',
        headers: {'Content-Type': 'application/json'},
        body: '{"name":"DevDesk"}',
      ),
      client: client,
      timeout: const Duration(seconds: 5),
    );

    expect(response.statusCode, 201);
  });

  test('timeout throws ApiFailure', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('late', 200);
    });

    expect(
      () => executeApiRequest(
        request: ApiRequest(method: 'GET', url: 'https://api.example.com'),
        client: client,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('invalid URL throws ApiFailure', () async {
    final client = MockClient((request) async => http.Response('', 200));

    expect(
      () => executeApiRequest(
        request: ApiRequest(method: 'GET', url: 'not-a-url'),
        client: client,
        timeout: const Duration(seconds: 5),
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
}
