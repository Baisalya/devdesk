import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/api_tester/models/api_request.dart';
import 'package:devdesk/features/api_tester/utils/api_code_snippets.dart';
import 'package:devdesk/features/api_tester/utils/api_environment_utils.dart';

void main() {
  test('environment variable replacement is local and explicit', () {
    final resolved = ApiEnvironmentUtils.resolveVariables(
      '{{baseUrl}}/users',
      {'baseUrl': 'https://api.example.com'},
    );

    expect(resolved, 'https://api.example.com/users');
  });

  test('code snippets are generated from request metadata', () {
    final request = ApiRequest(
      method: 'POST',
      url: 'https://api.example.com/users',
      headers: {'Content-Type': 'application/json'},
      queryParams: {'active': 'true'},
      body: '{"name":"DevDesk"}',
    );

    final curl = ApiCodeSnippets.curl(request);
    final dart = ApiCodeSnippets.dartHttp(request);
    final fetch = ApiCodeSnippets.javascriptFetch(request);

    expect(curl, contains('curl -X POST'));
    expect(curl, contains('Content-Type: application/json'));
    expect(curl, contains('active=true'));
    expect(dart, contains("http.Request('POST'"));
    expect(dart, isNot(contains('client.post(')));
    expect(fetch, contains('"method": "POST"'));
    expect(fetch, contains('"body": "{\\"name\\":\\"DevDesk\\"}"'));
  });
}
