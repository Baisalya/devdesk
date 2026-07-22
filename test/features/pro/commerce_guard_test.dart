import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/pro/data/commerce_config.dart';
import 'package:devdesk/features/pro/data/platform_purchase_adapters.dart';
import 'package:devdesk/features/pro/data/purchase_adapter.dart';
import 'package:devdesk/features/pro/domain/feature_access.dart';
import 'package:devdesk/features/pro/provider/feature_access_provider.dart';

void main() {
  test('commerce stays disabled even when build values are requested', () {
    const config = CommerceConfig(
      requestedEnabled: true,
      googlePlayProductId: 'devdesk_pro_android',
      microsoftStoreProductId: 'devdesk_pro_windows',
      verificationEndpoint: 'https://example.test/verify',
    );

    expect(CommerceConfig.implementationReady, isFalse);
    expect(config.enabled, isFalse);
    expect(config.blockingIssues, isNotEmpty);
    expect(
        createPlatformPurchaseAdapter(config), isA<DisabledPurchaseAdapter>());
  });

  test('every current capability remains available on Free', () {
    const entitlement = EntitlementSnapshot.freeDisabled();
    const access = FeatureAccessService(entitlement);

    for (final capability in AppCapability.values
        .where((capability) => capability.includedInFree)) {
      expect(
        access.canUse(capability),
        isTrue,
        reason: '${capability.label} is part of the permanent Free contract',
      );
    }
    for (final capability in AppCapability.values
        .where((capability) => !capability.includedInFree)) {
      expect(access.canUse(capability), isFalse);
      expect(access.requiresPro(capability), isTrue);
    }
  });

  test('disabled adapter can never start a purchase', () async {
    const adapter = DisabledPurchaseAdapter('disabled for test');

    expect(await adapter.isAvailable(), isFalse);
    expect(await adapter.queryProducts({'pro'}), isEmpty);
    await expectLater(
      adapter.purchase('pro'),
      throwsA(isA<Exception>()),
    );
  });
}
