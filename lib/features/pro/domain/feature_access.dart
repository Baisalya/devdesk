import 'package:flutter/foundation.dart';

/// Product capabilities are explicit so future monetization cannot
/// accidentally move an existing feature behind a paywall.
enum AppCapability {
  developerTools('Developer tools', includedInFree: true),
  localApiWorkspaces('Local API workspaces', includedInFree: true),
  markdownVault('Local Markdown vault', includedInFree: true),
  localBackup('Local backup and restore', includedInFree: true),
  externalFiles('External file editing', includedInFree: true),
  coreThemes('Six core themes and high contrast', includedInFree: true),
  accessibility('Accessibility features', includedInFree: true),
  encryptedCloudSync('Encrypted cloud sync', includedInFree: false),
  crossDeviceWorkspace('Cross-device workspace', includedInFree: false),
  teamSharing('Team sharing', includedInFree: false),
  scheduledCloudRuns('Scheduled cloud API runs', includedInFree: false),
  extendedCloudHistory('Extended cloud history', includedInFree: false),
  customThemeDesigner('Custom theme designer', includedInFree: false);

  final String label;
  final bool includedInFree;

  const AppCapability(this.label, {required this.includedInFree});
}

enum EntitlementSource { disabled, free, googlePlay, microsoftStore }

@immutable
class EntitlementSnapshot {
  final bool monetizationEnabled;
  final bool proActive;
  final EntitlementSource source;
  final DateTime? validUntil;

  const EntitlementSnapshot({
    required this.monetizationEnabled,
    required this.proActive,
    required this.source,
    this.validUntil,
  });

  const EntitlementSnapshot.freeDisabled()
      : monetizationEnabled = false,
        proActive = false,
        source = EntitlementSource.disabled,
        validUntil = null;

  bool canUse(AppCapability capability) {
    return capability.includedInFree || (monetizationEnabled && proActive);
  }
}
