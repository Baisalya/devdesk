import '../../../core/errors/failure.dart';
import 'mcp_models.dart';

abstract interface class McpServerAdapter {
  String get id;
  List<McpToolDescriptor> get tools;
  Future<McpToolResult> call(String toolName, Map<String, Object?> arguments);
}

class McpRegistry {
  final Map<String, McpServerAdapter> _servers;
  final Set<String> enabledServerIds;

  McpRegistry(
    Iterable<McpServerAdapter> servers, {
    this.enabledServerIds = const {},
  }) : _servers = {for (final server in servers) server.id: server};

  List<McpToolDescriptor> get visibleTools => [
        for (final id in enabledServerIds) ...?_servers[id]?.tools,
      ];

  Future<McpToolResult> execute(McpToolCall call) async {
    final separator = call.qualifiedName.indexOf(':');
    if (separator <= 0) {
      throw ValidationFailure(
        'MCP tool names must include the server ID.',
        code: 'DD-MCP-TOOL-NAME',
      );
    }
    final serverId = call.qualifiedName.substring(0, separator);
    final toolName = call.qualifiedName.substring(separator + 1);
    if (!enabledServerIds.contains(serverId)) {
      throw PermissionFailure(
        'This MCP server is not enabled.',
        code: 'DD-MCP-DISABLED',
      );
    }
    final server = _servers[serverId];
    if (server == null) {
      throw PlatformCapabilityFailure(
        'The configured MCP server is unavailable.',
        code: 'DD-MCP-UNAVAILABLE',
      );
    }
    McpToolDescriptor? descriptor;
    for (final candidate in server.tools) {
      if (candidate.name == toolName) descriptor = candidate;
    }
    if (descriptor == null) {
      throw ValidationFailure(
        'The requested MCP tool is not exposed by this server.',
        code: 'DD-MCP-NOT-FOUND',
      );
    }
    if (descriptor.access != McpToolAccess.readOnly && !call.userConfirmed) {
      throw PermissionFailure(
        'Confirm this MCP write or external action before it runs.',
        code: 'DD-MCP-CONFIRMATION',
      );
    }
    return server.call(toolName, Map.unmodifiable(call.arguments));
  }
}
