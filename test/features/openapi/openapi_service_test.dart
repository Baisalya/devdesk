import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/openapi/data/local_openapi_service.dart';
import 'package:devdesk/features/openapi/domain/openapi_models.dart';

void main() {
  const service = LocalOpenApiService();
  const source = '''
openapi: 3.0.3
info:
  title: Customer API
  description: Customer operations.
servers:
  - url: https://api.example.test
paths:
  /v1/customers:
    post:
      operationId: createCustomer
      summary: Create customer
      tags: [customers]
      parameters:
        - name: tenant_id
          in: header
          required: true
      requestBody:
        content:
          application/json:
            schema:
              \$ref: '#/components/schemas/Customer'
      responses:
        '201':
          description: Created
components:
  schemas:
    Customer:
      type: object
      required: [id]
      properties:
        id:
          type: string
        name:
          type: string
''';

  test('parses OpenAPI YAML operations, schemas and JSON pointers', () {
    final document = service.parse(source);

    expect(document.version, '3.0.3');
    expect(document.title, 'Customer API');
    expect(document.operations, hasLength(1));
    expect(document.operations.single.operationId, 'createCustomer');
    expect(document.operations.single.requiredParameters, ['tenant_id']);
    expect(document.operations.single.sourcePointer,
        '#/paths/~1v1~1customers/post');
    expect(document.schemas['Customer']?.propertyTypes['id'], 'string');
  });

  test('generates API requests and Markdown without mutating source', () {
    final document = service.parse(source);
    final collection = service.generateCollection(document);
    final markdown = service.generateMarkdown(document);

    expect(collection.name, 'Customer API');
    expect(collection.variables.single.key, 'base_url');
    expect(collection.variables.single.value, 'https://api.example.test');
    expect(collection.requests.single.url, '{{base_url}}/v1/customers');
    expect(collection.requests.single.method, 'POST');
    expect(collection.requests.single.description, contains('source_ref'));
    expect(markdown, contains('source_type: openapi'));
    expect(markdown, contains('## POST `/v1/customers`'));
    expect(document.source['openapi'], '3.0.3');
  });

  test('detects removed operations and property type changes as breaking', () {
    final previous = service.parse(source);
    final current = service.parse(source
        .replaceFirst('    post:', '    get:')
        .replaceFirst('          type: string\n        name:',
            '          type: integer\n        name:'));

    final changes = service.compare(previous, current);

    expect(
      changes.where((change) => change.code == 'OPENAPI-OPERATION-REMOVED'),
      hasLength(1),
    );
    expect(
      changes.where((change) => change.code == 'OPENAPI-OPERATION-ADDED'),
      hasLength(1),
    );
    expect(
      changes.where((change) => change.code == 'OPENAPI-PROPERTY-TYPE'),
      hasLength(1),
    );
    expect(
      changes
          .where((change) => change.severity == OpenApiChangeSeverity.breaking),
      hasLength(2),
    );
  });

  test('rejects non-OpenAPI, unsupported versions and missing titles', () {
    expect(
      () => service.parse('openapi: 2.0\ninfo: {title: Old}\npaths: {}'),
      throwsA(isA<ParsingFailure>()),
    );
    expect(
      () => service.parse('openapi: 3.0.0\ninfo: {}\npaths: {}'),
      throwsA(isA<ParsingFailure>()),
    );
    expect(
      () => service.parse('not: [valid'),
      throwsA(isA<ParsingFailure>()),
    );
  });
}
