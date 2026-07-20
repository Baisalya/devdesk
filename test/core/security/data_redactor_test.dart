import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/security/data_redactor.dart';
import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';

void main() {
  const canary = 'CANARY_SECRET_7b3d9a';

  test('redacts secrets from URL, headers, body, response, and errors', () {
    final url = DataRedactor.redactUrl(
      'https://example.test/path?token=$canary&q=visible',
    );
    expect(url, isNot(contains(canary)));
    expect(url, contains('q=visible'));

    final headers = DataRedactor.redactHeaders({
      'Authorization': 'Bearer $canary',
      'Accept': 'application/json',
      'X-Api-Key': canary,
    });
    expect(jsonEncode(headers), isNot(contains(canary)));
    expect(headers['Accept'], 'application/json');

    final response = DataRedactor.redactJsonText(
      '{"token":"$canary","nested":{"password":"$canary"},"ok":true}',
    );
    expect(response, isNot(contains(canary)));
    expect(response, contains('"ok":true'));

    final error = DataRedactor.safeError(
      'failed Authorization: Bearer $canary at C:\\Users\\Alice\\secret.txt alice@example.com',
    );
    expect(error, isNot(contains(canary)));
    expect(error, isNot(contains('alice@example.com')));
    expect(error, isNot(contains(r'C:\Users\Alice')));
  });

  test('workspace/history/response portable maps exclude canary secrets', () {
    final request = ApiRequestItem(
      id: 'request-1',
      name: 'Canary request',
      method: 'POST',
      url: 'https://example.test?access_token=$canary',
      headers: {'Authorization': 'Bearer $canary'},
      body: const ApiRequestBody(type: ApiRequestBodyType.rawJson).copyWith(
        raw: '{"password":"$canary"}',
      ),
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: canary,
      ),
      exampleResponse: '{"refresh_token":"$canary"}',
    );
    final response = ApiResponseRecord(
      id: 'response-1',
      method: 'POST',
      url: request.url,
      statusCode: 200,
      headers: {'Set-Cookie': 'session=$canary'},
      body: '{"api_key":"$canary"}',
      durationMs: 10,
      sizeBytes: 20,
    );
    final history = ApiHistoryItem(
      id: 'history-1',
      workspaceId: 'workspace-1',
      requestId: request.id,
      requestName: request.name,
      method: request.method,
      url: request.url,
      request: request,
      response: response,
    );

    expect(jsonEncode(request.toMap(includeSecrets: false)),
        isNot(contains(canary)));
    expect(jsonEncode(response.toMap(includeSecrets: false)),
        isNot(contains(canary)));
    expect(jsonEncode(history.toMap(includeSecrets: false)),
        isNot(contains(canary)));
  });

  test('typed failures expose stable safe diagnostic metadata', () {
    final failure = ApiFailure(
      'Connection timed out.',
      code: 'DD-API-CONNECT-TIMEOUT',
    );
    final display = DataRedactor.safeError(failure);

    expect(display, contains('Connection timed out.'));
    expect(display, contains('DD-API-CONNECT-TIMEOUT'));
    expect(display, contains(failure.correlationId));
    expect(failure.toDiagnosticMap(), {
      'code': 'DD-API-CONNECT-TIMEOUT',
      'severity': 'error',
      'category': 'network',
      'retryable': true,
      'correlationId': failure.correlationId,
    });
  });
}
