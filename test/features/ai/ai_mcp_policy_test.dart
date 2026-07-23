import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/ai/domain/ai_models.dart';
import 'package:devdesk/features/ai/domain/ai_service.dart';
import 'package:devdesk/features/mcp/domain/mcp_models.dart';
import 'package:devdesk/features/mcp/domain/mcp_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _Server implements McpServerAdapter {
  var calls = 0;

  @override
  String get id => 'local';

  @override
  List<McpToolDescriptor> get tools => const [
        McpToolDescriptor(
          serverId: 'local',
          name: 'read',
          description: 'Read metadata',
          access: McpToolAccess.readOnly,
        ),
        McpToolDescriptor(
          serverId: 'local',
          name: 'write',
          description: 'Write a file',
          access: McpToolAccess.writesWorkspace,
        ),
      ];

  @override
  Future<McpToolResult> call(
    String toolName,
    Map<String, Object?> arguments,
  ) async {
    calls++;
    return McpToolResult(summary: toolName);
  }
}

void main() {
  test('AI is disabled by default and redacts secret context', () {
    expect(
      () => AiRequestPolicy.prepare(
        settings: const AiProviderSettings(),
        instruction: 'Summarize',
        selectedContext: const [],
      ),
      throwsA(isA<PlatformCapabilityFailure>()),
    );
    final request = AiRequestPolicy.prepare(
      settings: const AiProviderSettings(
        provider: AiProviderKind.remote,
        disclosureScope: AiDisclosureScope.currentSelection,
      ),
      instruction: 'Explain',
      selectedContext: const [
        AiContextItem(
          reference: 'api-request:1',
          label: 'Request',
          content: 'Authorization: Bearer secret-token',
          mayContainSecrets: true,
        ),
      ],
    );
    expect(request.context.single.content, isNot(contains('secret-token')));
  });

  test('AI proposals require confirmation and fingerprints', () {
    const proposal = AiChangeProposal(
      summary: 'Edit doc',
      generatedRemotely: true,
      changes: [
        AiFileChange(
          workspaceId: 'w',
          relativePath: 'README.md',
          expectedFingerprint: 'abc',
          replacement: '# Updated',
        ),
      ],
    );
    expect(
      () => AiProposalGate.approve(proposal, userConfirmed: false),
      throwsA(isA<PermissionFailure>()),
    );
    expect(
      AiProposalGate.approve(proposal, userConfirmed: true),
      hasLength(1),
    );
  });

  test('MCP hides disabled servers and gates write tools', () async {
    final server = _Server();
    final disabled = McpRegistry([server]);
    expect(disabled.visibleTools, isEmpty);
    await expectLater(
      disabled.execute(const McpToolCall(qualifiedName: 'local:read')),
      throwsA(isA<PermissionFailure>()),
    );

    final enabled = McpRegistry([server], enabledServerIds: {'local'});
    await enabled.execute(const McpToolCall(qualifiedName: 'local:read'));
    await expectLater(
      enabled.execute(const McpToolCall(qualifiedName: 'local:write')),
      throwsA(isA<PermissionFailure>()),
    );
    await enabled.execute(
      const McpToolCall(qualifiedName: 'local:write', userConfirmed: true),
    );
    expect(server.calls, 2);
  });
}
