import 'package:flutter/foundation.dart';

@immutable
class OpenApiOperation {
  final String operationId;
  final String method;
  final String path;
  final String summary;
  final String description;
  final List<String> tags;
  final List<String> requiredParameters;
  final List<String> requestContentTypes;
  final List<String> responseCodes;
  final String sourcePointer;

  const OpenApiOperation({
    required this.operationId,
    required this.method,
    required this.path,
    required this.summary,
    required this.description,
    required this.tags,
    required this.requiredParameters,
    required this.requestContentTypes,
    required this.responseCodes,
    required this.sourcePointer,
  });
}

@immutable
class OpenApiSchemaSummary {
  final String name;
  final String type;
  final Set<String> requiredProperties;
  final Map<String, String> propertyTypes;

  const OpenApiSchemaSummary({
    required this.name,
    required this.type,
    required this.requiredProperties,
    required this.propertyTypes,
  });
}

@immutable
class OpenApiDocument {
  final String version;
  final String title;
  final String description;
  final List<String> servers;
  final List<OpenApiOperation> operations;
  final Map<String, OpenApiSchemaSummary> schemas;
  final Map<String, dynamic> source;
  final String fingerprint;

  const OpenApiDocument({
    required this.version,
    required this.title,
    required this.description,
    required this.servers,
    required this.operations,
    required this.schemas,
    required this.source,
    required this.fingerprint,
  });
}

enum OpenApiChangeSeverity { breaking, potentiallyBreaking, nonBreaking }

@immutable
class OpenApiChange {
  final OpenApiChangeSeverity severity;
  final String code;
  final String message;
  final String sourcePointer;

  const OpenApiChange({
    required this.severity,
    required this.code,
    required this.message,
    required this.sourcePointer,
  });
}
