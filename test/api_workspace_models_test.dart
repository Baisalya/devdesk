import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/api_tester/models/api_environment.dart';
import 'package:devdesk/features/api_tester/models/api_variable.dart';
import 'package:devdesk/features/api_tester/models/api_workspace_models.dart';
import 'package:devdesk/features/api_tester/utils/api_workspace_utils.dart';

void main() {
  test('workspace model serialization preserves nested API data', () {
    final workspace = ApiWorkspace(
      id: 'workspace-1',
      name: 'My Shopping App',
      description: 'Project APIs',
      environments: [
        ApiEnvironment(
          id: 'local',
          name: 'Local',
          baseUrl: 'http://10.0.2.2:3000',
          variables: const [ApiVariable(key: 'token', value: 'abc')],
        ),
      ],
      activeEnvironmentId: 'local',
      variables: const [ApiVariable(key: 'userId', value: '42')],
      collections: [
        ApiCollection(
          id: 'collection-1',
          name: 'Auth',
          folders: [
            ApiFolder(
              id: 'folder-1',
              name: 'Login',
              requests: [
                ApiRequestItem(
                  id: 'request-1',
                  name: 'Login',
                  method: 'POST',
                  url: '{{baseUrl}}/login',
                  body: const ApiRequestBody(
                    type: ApiRequestBodyType.rawJson,
                    raw: '{"email":"a@example.com"}',
                  ),
                  assertions: const [
                    ApiAssertion(
                      id: 'assert-1',
                      name: 'status == 200',
                      type: ApiAssertionType.statusCodeEquals,
                      expected: '200',
                    ),
                  ],
                  extractionRules: const [
                    ApiExtractionRule(
                      id: 'extract-1',
                      name: 'token',
                      source: ApiExtractionSource.jsonPath,
                      expression: r'$.token',
                      variableName: 'token',
                      isSecret: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final restored = ApiWorkspace.fromMap(workspace.toMap());

    expect(restored.name, 'My Shopping App');
    expect(restored.requestCount, 1);
    expect(restored.folderCount, 1);
    expect(restored.activeEnvironment?.variableMap['baseUrl'],
        'http://10.0.2.2:3000');
    expect(
        restored.collections.first.folders.first.requests.first.method, 'POST');
  });

  test('export sanitizes secrets by default', () {
    final workspace = ApiWorkspace(
      id: 'workspace-1',
      name: 'Secrets',
      saveSecrets: true,
      variables: const [
        ApiVariable(key: 'token', value: 'secret-token', isSecret: true),
      ],
      auth: const ApiAuthConfig(
        type: ApiAuthType.bearerToken,
        token: 'secret-token',
      ),
      collections: [
        ApiCollection(
          id: 'collection-1',
          name: 'Auth',
          requests: [
            ApiRequestItem(
              id: 'request-1',
              name: 'Get Me',
              method: 'GET',
              url: '{{baseUrl}}/me',
              headers: const {'Authorization': 'Bearer secret'},
            ),
          ],
        ),
      ],
    );

    final exported = ApiWorkspaceImportExport.exportWorkspace(workspace);
    final restored =
        ApiWorkspace.fromMap(exported['workspace'] as Map<String, dynamic>);

    expect(restored.saveSecrets, isFalse);
    expect(restored.auth.token, isEmpty);
    expect(restored.variables.single.value, isEmpty);
    expect(restored.collections.first.requests.first.headers,
        isNot(contains('Authorization')));
  });

  test('runner result summary calculates pass fail skipped and average', () {
    final result = ApiRunnerResult(
      id: 'run-1',
      workspaceId: 'workspace-1',
      collectionId: 'collection-1',
      targetName: 'Auth',
      environmentId: 'local',
      results: const [
        ApiRunnerRequestResult(
          requestId: 'one',
          requestName: 'One',
          passed: true,
          durationMs: 100,
        ),
        ApiRunnerRequestResult(
          requestId: 'two',
          requestName: 'Two',
          passed: false,
          durationMs: 300,
        ),
        ApiRunnerRequestResult(
          requestId: 'three',
          requestName: 'Three',
          passed: false,
          skipped: true,
        ),
      ],
    );

    expect(result.totalRequests, 3);
    expect(result.passed, 1);
    expect(result.failed, 1);
    expect(result.skipped, 1);
    expect(result.averageResponseTimeMs, 200);
  });
}
