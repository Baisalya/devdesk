import 'package:flutter/foundation.dart';

enum McpToolAccess { readOnly, writesWorkspace, externalSideEffect }

@immutable
class McpToolDescriptor {
  final String serverId;
  final String name;
  final String description;
  final McpToolAccess access;

  const McpToolDescriptor({
    required this.serverId,
    required this.name,
    required this.description,
    required this.access,
  });

  String get qualifiedName => '$serverId:$name';
}

@immutable
class McpToolCall {
  final String qualifiedName;
  final Map<String, Object?> arguments;
  final bool userConfirmed;

  const McpToolCall({
    required this.qualifiedName,
    this.arguments = const {},
    this.userConfirmed = false,
  });
}

@immutable
class McpToolResult {
  final String summary;
  final Map<String, Object?> data;

  const McpToolResult({required this.summary, this.data = const {}});
}
