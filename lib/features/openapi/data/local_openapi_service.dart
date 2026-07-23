import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import '../../../core/errors/failure.dart';
import '../../../core/files/external_file.dart';
import '../../api_tester/models/api_variable.dart';
import '../../api_tester/models/api_workspace_models.dart';
import '../domain/openapi_models.dart';
import '../domain/openapi_service.dart';

class LocalOpenApiService implements OpenApiService {
  static const _methods = {
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options',
    'trace',
  };

  const LocalOpenApiService();

  @override
  OpenApiDocument parse(String source, {String sourceName = 'openapi'}) {
    if (source.length > 10 * 1024 * 1024) {
      throw ParsingFailure(
        'OpenAPI document exceeds the 10 MB parsing limit.',
        code: 'DD-OPENAPI-LIMIT',
      );
    }
    final decoded = _decode(source);
    final version = decoded['openapi']?.toString() ?? '';
    if (!version.startsWith('3.')) {
      throw ParsingFailure(
        'Only OpenAPI 3.x documents are currently supported.',
        code: 'DD-OPENAPI-VERSION',
      );
    }
    final info = _map(decoded['info']);
    if ((info['title']?.toString() ?? '').trim().isEmpty) {
      throw ParsingFailure(
        'OpenAPI info.title is required.',
        code: 'DD-OPENAPI-TITLE',
      );
    }
    final operations = <OpenApiOperation>[];
    final paths = _map(decoded['paths']);
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      if (!path.startsWith('/')) {
        throw ParsingFailure(
          'OpenAPI path "$path" must start with /.',
          code: 'DD-OPENAPI-PATH',
        );
      }
      final pathItem = _map(pathEntry.value);
      final sharedParameters = _parameterNames(pathItem['parameters']);
      for (final operationEntry in pathItem.entries) {
        final method = operationEntry.key.toLowerCase();
        if (!_methods.contains(method)) continue;
        final operation = _map(operationEntry.value);
        final operationId = operation['operationId']?.toString().trim();
        final requestBody = _map(operation['requestBody']);
        final content = _map(requestBody['content']);
        final responses = _map(operation['responses']);
        operations.add(
          OpenApiOperation(
            operationId: operationId == null || operationId.isEmpty
                ? _derivedOperationId(method, path)
                : operationId,
            method: method.toUpperCase(),
            path: path,
            summary: operation['summary']?.toString() ?? '',
            description: operation['description']?.toString() ?? '',
            tags: _strings(operation['tags']),
            requiredParameters: {
              ...sharedParameters,
              ..._parameterNames(operation['parameters']),
            }.toList()
              ..sort(),
            requestContentTypes: content.keys.toList()..sort(),
            responseCodes: responses.keys.toList()..sort(),
            sourcePointer:
                '#/paths/${_pointerEscape(path)}/${method.toLowerCase()}',
          ),
        );
      }
    }
    operations.sort((left, right) {
      final path = left.path.compareTo(right.path);
      return path != 0 ? path : left.method.compareTo(right.method);
    });
    final schemas = <String, OpenApiSchemaSummary>{};
    final rawSchemas = _map(_map(decoded['components'])['schemas']);
    for (final entry in rawSchemas.entries) {
      final schema = _map(entry.value);
      final properties = _map(schema['properties']);
      schemas[entry.key] = OpenApiSchemaSummary(
        name: entry.key,
        type: schema['type']?.toString() ?? 'object',
        requiredProperties: _strings(schema['required']).toSet(),
        propertyTypes: {
          for (final property in properties.entries)
            property.key: _map(property.value)['type']?.toString() ?? 'unknown',
        },
      );
    }
    return OpenApiDocument(
      version: version,
      title: info['title'].toString(),
      description: info['description']?.toString() ?? '',
      servers: [
        for (final item in (decoded['servers'] as Iterable?) ?? const [])
          if (item is Map && item['url'] != null) item['url'].toString(),
      ],
      operations: operations,
      schemas: schemas,
      source: decoded,
      fingerprint: ExternalFileDetector.fingerprint(utf8.encode(source)),
    );
  }

  @override
  ApiCollection generateCollection(OpenApiDocument document) {
    final baseUrl = document.servers.isEmpty ? '' : document.servers.first;
    return ApiCollection(
      id: const Uuid().v4(),
      name: document.title,
      description:
          '${document.description}\nGenerated from OpenAPI ${document.version}; the source specification remains canonical.'
              .trim(),
      variables: [
        ApiVariable(
          key: 'base_url',
          value: baseUrl,
          description: 'Generated from the first OpenAPI server URL.',
        ),
      ],
      requests: [
        for (final operation in document.operations)
          ApiRequestItem(
            id: const Uuid().v4(),
            name: operation.summary.trim().isEmpty
                ? operation.operationId
                : operation.summary,
            description:
                '${operation.description}\nsource_ref: ${operation.sourcePointer}'
                    .trim(),
            method: operation.method,
            url: '{{base_url}}${operation.path}',
            body: _bodyFor(operation),
            tags: operation.tags,
          ),
      ],
    );
  }

  @override
  List<OpenApiChange> compare(
    OpenApiDocument previous,
    OpenApiDocument current,
  ) {
    final changes = <OpenApiChange>[];
    final oldOperations = {
      for (final item in previous.operations)
        '${item.method} ${item.path}': item,
    };
    final newOperations = {
      for (final item in current.operations)
        '${item.method} ${item.path}': item,
    };
    for (final entry in oldOperations.entries) {
      final next = newOperations[entry.key];
      if (next == null) {
        changes.add(OpenApiChange(
          severity: OpenApiChangeSeverity.breaking,
          code: 'OPENAPI-OPERATION-REMOVED',
          message: '${entry.key} was removed.',
          sourcePointer: entry.value.sourcePointer,
        ));
        continue;
      }
      final newlyRequired = next.requiredParameters
          .where((value) => !entry.value.requiredParameters.contains(value));
      for (final parameter in newlyRequired) {
        changes.add(OpenApiChange(
          severity: OpenApiChangeSeverity.breaking,
          code: 'OPENAPI-PARAMETER-REQUIRED',
          message: '${entry.key} now requires parameter $parameter.',
          sourcePointer: next.sourcePointer,
        ));
      }
    }
    for (final entry in newOperations.entries) {
      if (!oldOperations.containsKey(entry.key)) {
        changes.add(OpenApiChange(
          severity: OpenApiChangeSeverity.nonBreaking,
          code: 'OPENAPI-OPERATION-ADDED',
          message: '${entry.key} was added.',
          sourcePointer: entry.value.sourcePointer,
        ));
      }
    }
    for (final oldSchema in previous.schemas.entries) {
      final next = current.schemas[oldSchema.key];
      if (next == null) {
        changes.add(OpenApiChange(
          severity: OpenApiChangeSeverity.breaking,
          code: 'OPENAPI-SCHEMA-REMOVED',
          message: 'Schema ${oldSchema.key} was removed.',
          sourcePointer: '#/components/schemas/${oldSchema.key}',
        ));
        continue;
      }
      for (final property in oldSchema.value.propertyTypes.entries) {
        final nextType = next.propertyTypes[property.key];
        if (nextType == null) {
          changes.add(OpenApiChange(
            severity: OpenApiChangeSeverity.breaking,
            code: 'OPENAPI-PROPERTY-REMOVED',
            message: '${oldSchema.key}.${property.key} was removed.',
            sourcePointer:
                '#/components/schemas/${oldSchema.key}/properties/${property.key}',
          ));
        } else if (nextType != property.value) {
          changes.add(OpenApiChange(
            severity: OpenApiChangeSeverity.breaking,
            code: 'OPENAPI-PROPERTY-TYPE',
            message:
                '${oldSchema.key}.${property.key} changed from ${property.value} to $nextType.',
            sourcePointer:
                '#/components/schemas/${oldSchema.key}/properties/${property.key}',
          ));
        }
      }
    }
    return changes;
  }

  @override
  String generateMarkdown(OpenApiDocument document) {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('type: "API Collection"')
      ..writeln('title: ${jsonEncode(document.title)}')
      ..writeln('source_type: openapi')
      ..writeln('source_ref: "openapi:${document.fingerprint}"')
      ..writeln('---')
      ..writeln('# ${document.title}')
      ..writeln()
      ..writeln(document.description)
      ..writeln();
    for (final operation in document.operations) {
      buffer
        ..writeln('## ${operation.method} `${operation.path}`')
        ..writeln()
        ..writeln(operation.summary)
        ..writeln()
        ..writeln(operation.description)
        ..writeln()
        ..writeln('Source: `${operation.sourcePointer}`')
        ..writeln();
    }
    return buffer.toString();
  }

  static ApiRequestBody _bodyFor(OpenApiOperation operation) {
    if (operation.method == 'GET' || operation.method == 'HEAD') {
      return const ApiRequestBody();
    }
    if (operation.requestContentTypes.contains('application/json')) {
      return const ApiRequestBody(
        type: ApiRequestBodyType.rawJson,
        raw: '{}',
      );
    }
    if (operation.requestContentTypes.contains('application/xml')) {
      return const ApiRequestBody(type: ApiRequestBodyType.rawXml);
    }
    return const ApiRequestBody();
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final trimmed = source.trimLeft();
      final dynamic value = trimmed.startsWith('{')
          ? jsonDecode(source)
          : _plain(loadYaml(source));
      if (value is! Map) throw const FormatException();
      return Map<String, dynamic>.from(value);
    } on YamlException {
      throw ParsingFailure(
        'OpenAPI input is not valid YAML.',
        code: 'DD-OPENAPI-PARSE',
      );
    } on FormatException {
      throw ParsingFailure(
        'OpenAPI input is not valid JSON or YAML.',
        code: 'DD-OPENAPI-PARSE',
      );
    }
  }

  static dynamic _plain(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _plain(entry.value),
      };
    }
    if (value is Iterable) return value.map(_plain).toList();
    return value;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value
    };
  }

  static List<String> _strings(dynamic value) {
    return [
      for (final item in (value as Iterable?) ?? const []) item.toString(),
    ];
  }

  static Set<String> _parameterNames(dynamic value) {
    return {
      for (final item in (value as Iterable?) ?? const [])
        if (item is Map && item['required'] == true && item['name'] != null)
          item['name'].toString(),
    };
  }

  static String _derivedOperationId(String method, String path) {
    final words = path
        .split('/')
        .where((value) => value.isNotEmpty)
        .map((value) => value.replaceAll(RegExp(r'[{}]'), ''));
    return '$method-${words.join('-')}';
  }

  static String _pointerEscape(String value) {
    return value.replaceAll('~', '~0').replaceAll('/', '~1');
  }
}
