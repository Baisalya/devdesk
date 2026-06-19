import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/api_tester/models/api_environment.dart';
import 'package:devdesk/features/api_tester/models/api_variable.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/utils/api_workspace_utils.dart';

void main() {
  test(
      'variable resolution follows request environment collection workspace order',
      () {
    final values = ApiWorkspaceVariables.merge(
      workspace: const [ApiVariable(key: 'token', value: 'workspace')],
      collection: const [ApiVariable(key: 'token', value: 'collection')],
      environmentMap: const {
        'baseUrl': 'https://dev-api.example.com',
        'token': 'environment',
      },
      request: const [ApiVariable(key: 'token', value: 'request')],
    );

    final resolved = ApiWorkspaceVariables.resolve(
      '{{baseUrl}}/users?token={{token}}',
      values,
    );

    expect(
        resolved.resolved, 'https://dev-api.example.com/users?token=request');
    expect(resolved.hasMissing, isFalse);
  });

  test('missing variables are detected and preserved', () {
    final resolved = ApiWorkspaceVariables.resolve(
      '{{baseUrl}}/users/{{missing}}',
      {'baseUrl': 'https://api.example.com'},
    );

    expect(resolved.resolved, 'https://api.example.com/users/{{missing}}');
    expect(resolved.missingVariables, ['missing']);
  });

  test('auth inheritance applies request collection workspace precedence', () {
    final inherited = ApiAuthResolver.effectiveAuth(
      workspaceAuth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: 'workspace-token',
      ),
      collectionAuth: const ApiAuthConfig(
        type: ApiAuthType.apiKeyHeader,
        apiKeyName: 'X-Key',
        apiKeyValue: 'collection-key',
      ),
      requestAuth: const ApiAuthConfig.inherit(),
    );

    expect(inherited.type, ApiAuthType.apiKeyHeader);

    final disabled = ApiAuthResolver.effectiveAuth(
      workspaceAuth: inherited,
      requestAuth: const ApiAuthConfig.noAuth(),
    );

    expect(disabled.type, ApiAuthType.noAuth);
  });

  test('request composer builds URL query auth body and unresolved warnings',
      () {
    final workspace = ApiWorkspace(
      id: 'workspace',
      name: 'Workspace',
      environments: [
        ApiEnvironment(
          id: 'dev',
          name: 'Development',
          baseUrl: 'https://dev-api.example.com',
        ),
      ],
      activeEnvironmentId: 'dev',
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: '{{token}}',
      ),
      variables: const [ApiVariable(key: 'token', value: 'abc')],
    );
    final request = ApiRequestItem(
      id: 'request',
      name: 'Users',
      method: 'POST',
      url: '{{baseUrl}}/users/{{missing}}',
      queryParams: const {'q': 'devdesk'},
      body: const ApiRequestBody(
        type: ApiRequestBodyType.formUrlEncoded,
        formFields: {'name': 'DevDesk'},
      ),
    );

    final prepared = ApiWorkspaceRequestComposer.prepare(
      workspace: workspace,
      collection: null,
      folder: null,
      request: request,
      temporaryVariables: const {},
    );

    expect(prepared.url, 'https://dev-api.example.com/users/{{missing}}');
    expect(prepared.unresolvedVariables, ['missing']);
    expect(prepared.headers['Authorization'], 'Bearer abc');
    expect(prepared.formFields, {'name': 'DevDesk'});
  });

  test('JSON body tools validate format and minify', () {
    expect(ApiJsonBodyTools.validate('{"ok":true}'), isNull);
    expect(ApiJsonBodyTools.validate('{bad'), isNotNull);
    expect(ApiJsonBodyTools.format('{"ok":true}'), contains('"ok": true'));
    expect(ApiJsonBodyTools.minify('{ "ok" : true }'), '{"ok":true}');
  });

  test('assertions evaluate status time json header and body checks', () {
    final response = ApiResponseRecord(
      id: 'response',
      method: 'GET',
      url: 'https://api.example.com',
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: '{"data":{"token":"abc"}}',
      durationMs: 120,
      sizeBytes: 24,
    );
    final results = ApiAssertionEvaluator.evaluate(
      const [
        ApiAssertion(
          id: 'status',
          name: 'status',
          type: ApiAssertionType.statusCodeEquals,
          expected: '200',
        ),
        ApiAssertion(
          id: 'time',
          name: 'time',
          type: ApiAssertionType.responseTimeLessThan,
          expected: '1000',
        ),
        ApiAssertion(
          id: 'json-exists',
          name: 'json exists',
          type: ApiAssertionType.jsonPathExists,
          target: r'$.data.token',
        ),
        ApiAssertion(
          id: 'json-equals',
          name: 'json equals',
          type: ApiAssertionType.jsonPathEquals,
          target: r'$.data.token',
          expected: 'abc',
        ),
        ApiAssertion(
          id: 'header',
          name: 'header',
          type: ApiAssertionType.headerExists,
          target: 'Content-Type',
        ),
        ApiAssertion(
          id: 'body',
          name: 'body',
          type: ApiAssertionType.bodyContains,
          expected: 'token',
        ),
      ],
      response,
    );

    expect(results.every((result) => result.passed), isTrue);
  });

  test('extractions read JSON path header and regex body safely', () {
    final response = ApiResponseRecord(
      id: 'response',
      method: 'POST',
      url: 'https://api.example.com/login',
      statusCode: 200,
      headers: const {'x-request-id': 'req-1'},
      body: '{"token":"abc","message":"body-id=99"}',
      durationMs: 50,
      sizeBytes: 24,
    );

    final results = ApiExtractionEvaluator.extract(
      const [
        ApiExtractionRule(
          id: 'json',
          name: 'json',
          source: ApiExtractionSource.jsonPath,
          expression: r'$.token',
          variableName: 'token',
          isSecret: true,
        ),
        ApiExtractionRule(
          id: 'header',
          name: 'header',
          source: ApiExtractionSource.header,
          expression: 'X-Request-Id',
          variableName: 'requestId',
        ),
        ApiExtractionRule(
          id: 'regex',
          name: 'regex',
          source: ApiExtractionSource.regexBody,
          expression: r'body-id=(\d+)',
          variableName: 'bodyId',
        ),
      ],
      response,
    );

    expect(results.map((result) => result.value), ['abc', 'req-1', '99']);
    expect(results.first.displayValue, '••••••••');
  });

  test('DevDesk and Postman import previews validate schema', () {
    final document = ApiWorkspaceImportExport.exportWorkspace(
      ApiWorkspace(
        id: 'workspace',
        name: 'Workspace',
        collections: [
          ApiCollection(
            id: 'collection',
            name: 'Collection',
            requests: [
              ApiRequestItem(
                id: 'request',
                name: 'Users',
                method: 'GET',
                url: 'https://api.example.com/users',
              ),
            ],
          ),
        ],
      ),
    );

    expect(ApiWorkspaceImportExport.preview(document).requestsCount, 1);

    final postman = {
      'info': {'name': 'Postman Demo'},
      'item': [
        {
          'name': 'Users',
          'request': {
            'method': 'GET',
            'url': {'raw': 'https://api.example.com/users'},
          },
        },
      ],
    };

    expect(ApiWorkspaceImportExport.preview(postman).sourceType,
        'Postman collection');
  });
}
