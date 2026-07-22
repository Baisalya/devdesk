import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/feature_access.dart';
import 'entitlement_provider.dart';

final featureAccessProvider = Provider<FeatureAccessService>((ref) {
  return FeatureAccessService(ref.watch(entitlementProvider));
});

/// The single feature-gating boundary for future services. Existing routes do
/// not call this service because every capability currently shipped is Free.
class FeatureAccessService {
  final EntitlementSnapshot entitlement;

  const FeatureAccessService(this.entitlement);

  bool canUse(AppCapability capability) => entitlement.canUse(capability);

  bool requiresPro(AppCapability capability) {
    return !capability.includedInFree && !canUse(capability);
  }
}
