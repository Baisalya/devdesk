import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/utils/api_workspace_executor.dart';
import 'package:devdesk/features/api_tester/utils/api_workspace_utils.dart';

ApiPreparedRequest _prepared({
  ApiRequestBodyType type = ApiRequestBodyType.none,
  String method = 'POST',
  String? body,
  Map<String, String> formFields = const {},
  String url = 'https://example.test/submit',
}) {
  final source = ApiRequestItem(
    id: 'request-1',
    name: 'Request',
    method: method,
    url: url,
    body: ApiRequestBody(type: type, raw: body ?? '', formFields: formFields),
  );
  return ApiPreparedRequest(
    source: source,
    method: method,
    url: url,
    headers: const {},
    queryParams: const {},
    bodyType: type,
    body: body,
    formFields: formFields,
    timeout: const Duration(seconds: 2),
    followRedirects: true,
    unresolvedVariables: const [],
  );
}

void main() {
  test('URL-encoded form sends encoded fields with correct content type',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['content-type'],
          contains('application/x-www-form-urlencoded'));
      expect(request.bodyFields, {'name': 'Dev Desk', 'symbol': 'a+b'});
      return http.Response('ok', 200);
    });

    final response = await ApiWorkspaceExecutor.execute(
      prepared: _prepared(
        type: ApiRequestBodyType.formUrlEncoded,
        formFields: const {'name': 'Dev Desk', 'symbol': 'a+b'},
      ),
      client: client,
    );
    expect(response.statusCode, 200);
  });

  test('advertised multipart sends text fields as multipart form data',
      () async {
    final client = MockClient((request) async {
      expect(
          request.headers['content-type'], startsWith('multipart/form-data;'));
      expect(request.body, contains('name="note"'));
      expect(request.body, contains('hello'));
      return http.Response('created', 201);
    });

    final response = await ApiWorkspaceExecutor.execute(
      prepared: _prepared(
        type: ApiRequestBodyType.multipartFormData,
        formFields: const {'note': 'hello'},
      ),
      client: client,
    );
    expect(response.statusCode, 201);
  });

  test('invalid JSON is rejected before network send', () async {
    var sent = false;
    final client = MockClient((request) async {
      sent = true;
      return http.Response('', 200);
    });

    await expectLater(
      ApiWorkspaceExecutor.execute(
        prepared: _prepared(
          type: ApiRequestBodyType.rawJson,
          body: '{invalid',
        ),
        client: client,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(sent, isFalse);
  });

  test('XML, YAML, HTML and GraphQL bodies use explicit content types',
      () async {
    final cases = <ApiRequestBodyType, (String, String)>{
      ApiRequestBodyType.rawXml: (
        '<root><value>1</value></root>',
        'application/xml'
      ),
      ApiRequestBodyType.rawYaml: (
        'name: DevDesk\nenabled: true',
        'application/yaml'
      ),
      ApiRequestBodyType.rawHtml: ('<strong>DevDesk</strong>', 'text/html'),
      ApiRequestBodyType.graphql: (
        'query { viewer { id } }',
        'application/json'
      ),
    };
    for (final entry in cases.entries) {
      final client = MockClient((request) async {
        expect(request.headers['content-type'], contains(entry.value.$2));
        if (entry.key == ApiRequestBodyType.graphql) {
          expect(request.body, contains('query'));
          expect(request.body, contains('viewer'));
        }
        return http.Response('ok', 200);
      });
      final response = await ApiWorkspaceExecutor.execute(
        prepared: _prepared(type: entry.key, body: entry.value.$1),
        client: client,
      );
      expect(response.statusCode, 200);
    }
  });

  test('malformed XML, YAML and GraphQL are rejected before network send',
      () async {
    var sends = 0;
    final client = MockClient((request) async {
      sends++;
      return http.Response('', 200);
    });
    final invalid = <ApiRequestBodyType, String>{
      ApiRequestBodyType.rawXml: '<root>',
      ApiRequestBodyType.rawYaml: 'value: [unterminated',
      ApiRequestBodyType.graphql: 'query { viewer { id }',
    };
    for (final entry in invalid.entries) {
      await expectLater(
        ApiWorkspaceExecutor.execute(
          prepared: _prepared(type: entry.key, body: entry.value),
          client: client,
        ),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(sends, 0);
  });

  test('GET multipart and URL credentials are rejected safely', () async {
    final client = MockClient((request) async => http.Response('', 200));
    await expectLater(
      ApiWorkspaceExecutor.execute(
        prepared: _prepared(
          type: ApiRequestBodyType.multipartFormData,
          method: 'GET',
        ),
        client: client,
      ),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      ApiWorkspaceExecutor.execute(
        prepared: _prepared(url: 'https://user:pass@example.test'),
        client: client,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
}
