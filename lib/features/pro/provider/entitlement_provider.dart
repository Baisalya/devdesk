import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/commerce_config.dart';
import '../domain/commerce_models.dart';
import '../domain/feature_access.dart';

final commerceConfigProvider = Provider<CommerceConfig>((ref) {
  return const CommerceConfig.fromEnvironment();
});

final entitlementProvider =
    StateNotifierProvider<EntitlementController, EntitlementSnapshot>((ref) {
  final config = ref.watch(commerceConfigProvider);
  return EntitlementController(config);
});

class EntitlementController extends StateNotifier<EntitlementSnapshot> {
  final CommerceConfig config;

  EntitlementController(this.config)
      : super(
          config.enabled
              ? const EntitlementSnapshot(
                  monetizationEnabled: true,
                  proActive: false,
                  source: EntitlementSource.free,
                )
              : const EntitlementSnapshot.freeDisabled(),
        );

  void applyVerified(VerifiedEntitlement entitlement) {
    if (!config.enabled) return;
    state = EntitlementSnapshot(
      monetizationEnabled: true,
      proActive: entitlement.active,
      source: switch (entitlement.platform) {
        PurchasePlatform.googlePlay => EntitlementSource.googlePlay,
        PurchasePlatform.microsoftStore => EntitlementSource.microsoftStore,
        PurchasePlatform.unsupported => EntitlementSource.free,
      },
      validUntil: entitlement.validUntil,
    );
  }

  void clearPro() {
    state = EntitlementSnapshot(
      monetizationEnabled: config.enabled,
      proActive: false,
      source:
          config.enabled ? EntitlementSource.free : EntitlementSource.disabled,
    );
  }
}
