import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/commerce_models.dart';
import 'commerce_config.dart';
import 'purchase_adapter.dart';

PurchaseAdapter createPlatformPurchaseAdapter(CommerceConfig config) {
  if (!config.enabled) {
    return DisabledPurchaseAdapter(
      config.blockingIssues.join(' '),
    );
  }
  if (kIsWeb) {
    return const DisabledPurchaseAdapter(
      'Purchases are not supported on this platform.',
    );
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => GooglePlayPurchaseAdapter(),
    TargetPlatform.windows => MicrosoftStorePurchaseAdapter(),
    _ => const DisabledPurchaseAdapter(
        'Purchases are not supported on this platform.',
      ),
  };
}

abstract class _MethodChannelPurchaseAdapter implements PurchaseAdapter {
  final MethodChannel _channel;

  _MethodChannelPurchaseAdapter(String channelName)
      : _channel = MethodChannel(channelName);

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> productIds) async {
    final raw = await _invokeList(
      'queryProducts',
      {'productIds': productIds.toList(growable: false)},
    );
    return raw.whereType<Map>().map(StoreProduct.fromMap).toList();
  }

  @override
  Future<StoreTransaction> purchase(String productId) async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'purchase',
      {'productId': productId},
    );
    if (raw == null || raw['verificationToken'] is! String) {
      throw const BillingUnavailableException(
        'The store did not return a verifiable transaction.',
      );
    }
    return StoreTransaction(
      productId: raw['productId'] as String? ?? productId,
      verificationToken: raw['verificationToken'] as String,
      platform: platform,
    );
  }

  @override
  Future<List<StoreTransaction>> restore() async {
    final raw = await _invokeList('restore', null);
    return raw.whereType<Map>().where((item) {
      return item['verificationToken'] is String;
    }).map((item) {
      return StoreTransaction(
        productId: item['productId'] as String? ?? '',
        verificationToken: item['verificationToken'] as String,
        platform: platform,
      );
    }).toList();
  }

  Future<List<dynamic>> _invokeList(
    String method,
    Map<String, Object>? arguments,
  ) async {
    try {
      return await _channel.invokeListMethod<dynamic>(method, arguments) ??
          const [];
    } on MissingPluginException {
      throw const BillingUnavailableException(
        'The native store integration is not installed in this build.',
      );
    }
  }
}

class GooglePlayPurchaseAdapter extends _MethodChannelPurchaseAdapter {
  GooglePlayPurchaseAdapter()
      : super('com.baishalya.devdesk/billing/google_play');

  @override
  PurchasePlatform get platform => PurchasePlatform.googlePlay;
}

class MicrosoftStorePurchaseAdapter extends _MethodChannelPurchaseAdapter {
  MicrosoftStorePurchaseAdapter()
      : super('com.baishalya.devdesk/billing/microsoft_store');

  @override
  PurchasePlatform get platform => PurchasePlatform.microsoftStore;
}
