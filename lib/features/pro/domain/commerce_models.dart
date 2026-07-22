import 'package:flutter/foundation.dart';

enum PurchasePlatform { googlePlay, microsoftStore, unsupported }

@immutable
class StoreProduct {
  final String id;
  final String title;
  final String description;
  final String displayPrice;

  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.displayPrice,
  });

  factory StoreProduct.fromMap(Map<dynamic, dynamic> map) {
    return StoreProduct(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'DevDesk Pro',
      description: map['description'] as String? ?? '',
      displayPrice: map['displayPrice'] as String? ?? '',
    );
  }
}

@immutable
class StoreTransaction {
  final String productId;
  final String verificationToken;
  final PurchasePlatform platform;

  const StoreTransaction({
    required this.productId,
    required this.verificationToken,
    required this.platform,
  });
}

@immutable
class VerifiedEntitlement {
  final bool active;
  final DateTime? validUntil;
  final PurchasePlatform platform;

  const VerifiedEntitlement({
    required this.active,
    required this.platform,
    this.validUntil,
  });
}

class BillingUnavailableException implements Exception {
  final String message;

  const BillingUnavailableException(this.message);

  @override
  String toString() => message;
}
