import 'package:flutter/foundation.dart';

@immutable
class CommerceConfig {
  /// This remains false until both native store integrations and the receipt
  /// verification service have passed production certification.
  static const bool implementationReady = false;

  final bool requestedEnabled;
  final String googlePlayProductId;
  final String microsoftStoreProductId;
  final String verificationEndpoint;

  const CommerceConfig({
    required this.requestedEnabled,
    required this.googlePlayProductId,
    required this.microsoftStoreProductId,
    required this.verificationEndpoint,
  });

  const CommerceConfig.fromEnvironment()
      : requestedEnabled = const bool.fromEnvironment(
          'DEVDESK_MONETIZATION_ENABLED',
          defaultValue: false,
        ),
        googlePlayProductId = const String.fromEnvironment(
          'DEVDESK_GOOGLE_PLAY_PRO_PRODUCT_ID',
        ),
        microsoftStoreProductId = const String.fromEnvironment(
          'DEVDESK_MICROSOFT_STORE_PRO_PRODUCT_ID',
        ),
        verificationEndpoint = const String.fromEnvironment(
          'DEVDESK_ENTITLEMENT_VERIFICATION_ENDPOINT',
        );

  bool get enabled => requestedEnabled && blockingIssues.isEmpty;

  List<String> get blockingIssues {
    return [
      if (!implementationReady)
        'Native billing and server verification are not certified.',
      if (googlePlayProductId.trim().isEmpty)
        'Google Play product ID is missing.',
      if (microsoftStoreProductId.trim().isEmpty)
        'Microsoft Store product ID is missing.',
      if (!verificationEndpoint.trim().startsWith('https://'))
        'A secure entitlement verification endpoint is missing.',
    ];
  }
}
