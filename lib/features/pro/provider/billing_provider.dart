import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_purchase_adapters.dart';
import '../data/purchase_adapter.dart';
import '../domain/commerce_models.dart';
import 'entitlement_provider.dart';

enum BillingStatus { disabled, loading, ready, purchasing, error }

@immutable
class BillingState {
  final BillingStatus status;
  final List<StoreProduct> products;
  final String? message;

  const BillingState({
    required this.status,
    this.products = const [],
    this.message,
  });
}

final purchaseAdapterProvider = Provider<PurchaseAdapter>((ref) {
  return createPlatformPurchaseAdapter(ref.watch(commerceConfigProvider));
});

final purchaseVerificationProvider = Provider<PurchaseVerificationGateway>(
  (ref) => const RejectingPurchaseVerificationGateway(),
);

final billingProvider =
    StateNotifierProvider<BillingController, BillingState>((ref) {
  final controller = BillingController(
    ref: ref,
    adapter: ref.watch(purchaseAdapterProvider),
    verifier: ref.watch(purchaseVerificationProvider),
  );
  controller.initialize();
  return controller;
});

class BillingController extends StateNotifier<BillingState> {
  final Ref ref;
  final PurchaseAdapter adapter;
  final PurchaseVerificationGateway verifier;

  BillingController({
    required this.ref,
    required this.adapter,
    required this.verifier,
  }) : super(const BillingState(status: BillingStatus.disabled));

  Future<void> initialize() async {
    final config = ref.read(commerceConfigProvider);
    if (!config.enabled) {
      state = BillingState(
        status: BillingStatus.disabled,
        message: config.blockingIssues.join(' '),
      );
      return;
    }
    state = const BillingState(status: BillingStatus.loading);
    try {
      if (!await adapter.isAvailable()) {
        throw const BillingUnavailableException(
          'The platform store is unavailable.',
        );
      }
      final productId = switch (adapter.platform) {
        PurchasePlatform.googlePlay => config.googlePlayProductId,
        PurchasePlatform.microsoftStore => config.microsoftStoreProductId,
        PurchasePlatform.unsupported => '',
      };
      final products = await adapter.queryProducts({productId});
      state = BillingState(status: BillingStatus.ready, products: products);
    } catch (error) {
      state = BillingState(status: BillingStatus.error, message: '$error');
    }
  }

  Future<void> purchase(StoreProduct product) async {
    if (state.status != BillingStatus.ready) return;
    state = BillingState(
      status: BillingStatus.purchasing,
      products: state.products,
    );
    try {
      final transaction = await adapter.purchase(product.id);
      final verified = await verifier.verify(transaction);
      ref.read(entitlementProvider.notifier).applyVerified(verified);
      await initialize();
    } catch (error) {
      state = BillingState(
        status: BillingStatus.error,
        products: state.products,
        message: '$error',
      );
    }
  }

  Future<void> restore() async {
    final config = ref.read(commerceConfigProvider);
    if (!config.enabled) return;
    state = BillingState(
      status: BillingStatus.loading,
      products: state.products,
    );
    try {
      final transactions = await adapter.restore();
      for (final transaction in transactions) {
        final verified = await verifier.verify(transaction);
        if (verified.active) {
          ref.read(entitlementProvider.notifier).applyVerified(verified);
          break;
        }
      }
      await initialize();
    } catch (error) {
      state = BillingState(
        status: BillingStatus.error,
        products: state.products,
        message: '$error',
      );
    }
  }
}
