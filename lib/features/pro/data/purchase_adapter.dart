import '../domain/commerce_models.dart';

abstract interface class PurchaseAdapter {
  PurchasePlatform get platform;

  Future<bool> isAvailable();

  Future<List<StoreProduct>> queryProducts(Set<String> productIds);

  Future<StoreTransaction> purchase(String productId);

  Future<List<StoreTransaction>> restore();
}

class DisabledPurchaseAdapter implements PurchaseAdapter {
  final String reason;

  const DisabledPurchaseAdapter(this.reason);

  @override
  PurchasePlatform get platform => PurchasePlatform.unsupported;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> productIds) async =>
      const [];

  @override
  Future<StoreTransaction> purchase(String productId) async {
    throw BillingUnavailableException(reason);
  }

  @override
  Future<List<StoreTransaction>> restore() async => const [];
}

abstract interface class PurchaseVerificationGateway {
  Future<VerifiedEntitlement> verify(StoreTransaction transaction);
}

/// Production builds must replace this only after a server-side verifier is
/// deployed. Client-only purchase tokens never grant Pro access.
class RejectingPurchaseVerificationGateway
    implements PurchaseVerificationGateway {
  const RejectingPurchaseVerificationGateway();

  @override
  Future<VerifiedEntitlement> verify(StoreTransaction transaction) async {
    throw const BillingUnavailableException(
      'Secure purchase verification is not available in this build.',
    );
  }
}
