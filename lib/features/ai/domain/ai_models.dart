import 'package:flutter/foundation.dart';

enum AiProviderKind { disabled, local, remote }

enum AiDisclosureScope { none, currentSelection, selectedDocuments, workspace }

@immutable
class AiProviderSettings {
  final AiProviderKind provider;
  final AiDisclosureScope disclosureScope;
  final String endpoint;
  final bool allowSecretValues;

  const AiProviderSettings({
    this.provider = AiProviderKind.disabled,
    this.disclosureScope = AiDisclosureScope.none,
    this.endpoint = '',
    this.allowSecretValues = false,
  });

  bool get enabled => provider != AiProviderKind.disabled;
}

@immutable
class AiContextItem {
  final String reference;
  final String label;
  final String content;
  final bool mayContainSecrets;

  const AiContextItem({
    required this.reference,
    required this.label,
    required this.content,
    this.mayContainSecrets = false,
  });
}

@immutable
class AiRequestEnvelope {
  final String instruction;
  final List<AiContextItem> context;
  final AiDisclosureScope disclosedScope;

  const AiRequestEnvelope({
    required this.instruction,
    required this.context,
    required this.disclosedScope,
  });
}

@immutable
class AiFileChange {
  final String workspaceId;
  final String relativePath;
  final String expectedFingerprint;
  final String replacement;

  const AiFileChange({
    required this.workspaceId,
    required this.relativePath,
    required this.expectedFingerprint,
    required this.replacement,
  });
}

@immutable
class AiChangeProposal {
  final String summary;
  final List<AiFileChange> changes;
  final bool generatedRemotely;

  const AiChangeProposal({
    required this.summary,
    required this.changes,
    required this.generatedRemotely,
  });
}
