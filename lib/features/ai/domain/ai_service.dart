import '../../../core/errors/failure.dart';
import '../../../core/security/data_redactor.dart';
import 'ai_models.dart';

abstract interface class AiAssistant {
  Future<AiChangeProposal> propose(AiRequestEnvelope request);
}

class DisabledAiAssistant implements AiAssistant {
  const DisabledAiAssistant();

  @override
  Future<AiChangeProposal> propose(AiRequestEnvelope request) {
    throw PlatformCapabilityFailure(
      'AI assistance is disabled. Choose a provider and disclosure scope first.',
      code: 'DD-AI-DISABLED',
    );
  }
}

class AiRequestPolicy {
  const AiRequestPolicy._();

  static AiRequestEnvelope prepare({
    required AiProviderSettings settings,
    required String instruction,
    required List<AiContextItem> selectedContext,
  }) {
    if (!settings.enabled ||
        settings.disclosureScope == AiDisclosureScope.none) {
      throw PlatformCapabilityFailure(
        'AI is disabled or no disclosure scope was approved.',
        code: 'DD-AI-CONSENT',
      );
    }
    final sanitized = selectedContext.map((item) {
      if (!item.mayContainSecrets || settings.allowSecretValues) return item;
      return AiContextItem(
        reference: item.reference,
        label: item.label,
        content: DataRedactor.redactText(item.content),
        mayContainSecrets: false,
      );
    }).toList(growable: false);
    return AiRequestEnvelope(
      instruction: instruction,
      context: sanitized,
      disclosedScope: settings.disclosureScope,
    );
  }
}

class AiProposalGate {
  const AiProposalGate._();

  static List<AiFileChange> approve(
    AiChangeProposal proposal, {
    required bool userConfirmed,
  }) {
    if (!userConfirmed) {
      throw PermissionFailure(
        'Review and approve the proposed file changes before applying them.',
        code: 'DD-AI-APPROVAL',
      );
    }
    if (proposal.changes.any(
      (change) =>
          change.relativePath.isEmpty || change.expectedFingerprint.isEmpty,
    )) {
      throw ValidationFailure(
        'Every AI change must target a versioned workspace file.',
        code: 'DD-AI-PROPOSAL',
      );
    }
    return List.unmodifiable(proposal.changes);
  }
}
