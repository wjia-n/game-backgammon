import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Store service for backgammon: a single cosmetic Gold Star badge.
///
/// Product ID (the user creates this in Play Console / App Store Connect):
/// - `backgammonstar` — NON-CONSUMABLE Gold Star badge, $1.99.
///
/// Until the product exists in the store (or on any store error) the
/// service exposes [storeReady] = false and the UI shows an honest
/// "available after store setup" state — never a fake buy button.
/// The badge is cosmetic only: it changes nothing in the game and
/// nothing in the game depends on it.
class StoreService {
  static const starId = 'backgammonstar';
  static const productIds = {starId};
  ProductDetails? get proProduct => null;

  final InAppPurchase _iap = InAppPurchase.instance;

  bool available = false;
  bool storeReady = false; // true once real products are queryable
  List<ProductDetails> products = [];
  String? error;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Callbacks the UI wires up.
  final ValueNotifier<String?> lastThanks = ValueNotifier(null);
  final ValueNotifier<bool> proPurchased = ValueNotifier(true);
  final ValueNotifier<bool> starOwned = ValueNotifier(false);
  final ValueNotifier<bool> purchaseInProgress = ValueNotifier(false);
  final ValueNotifier<String?> purchaseError = ValueNotifier(null);

  ProductDetails? get starProduct => _byId(starId);

  ProductDetails? _byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      available = await _iap.isAvailable();
      if (!available) {
        error = 'Store unavailable on this device';
        return;
      }
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (_) {},
        cancelOnError: false,
      );
      final resp = await _iap.queryProductDetails(productIds);
      if (resp.error != null) {
        error = 'Could not reach the store';
        return;
      }
      products = resp.productDetails;
      if (resp.notFoundIDs.isNotEmpty) {
        error = 'Available after store setup';
        return;
      }
      storeReady = products.isNotEmpty;
      if (!storeReady) error = 'Available after store setup';
    } catch (_) {
      available = false;
      error = 'Store error';
    }
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == starId) {
          starOwned.value = true;
          lastThanks.value = 'Thank you! You earned a Gold Star.';
        }
      } else if (p.status == PurchaseStatus.error) {
        purchaseError.value = 'Purchase failed — please try again.';
      } else if (p.status == PurchaseStatus.canceled) {
        purchaseError.value = null;
      }
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored ||
          p.status == PurchaseStatus.canceled ||
          p.status == PurchaseStatus.error) {
        purchaseInProgress.value = false;
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p).catchError((_) {});
      }
    }
  }

  Future<void> buyPro() async {
    // No-op: kept for API compatibility; there is no gated content.
  }

  Future<void> buyStar(ProductDetails product) async {
    purchaseError.value = null;
    purchaseInProgress.value = true;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      purchaseInProgress.value = false;
      purchaseError.value = 'Purchase failed — please try again.';
    }
  }

  Future<void> restore() async {
    purchaseError.value = null;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      purchaseError.value = 'Restore failed — please try again.';
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    lastThanks.dispose();
    starOwned.dispose();
    purchaseInProgress.dispose();
    purchaseError.dispose();
  }
}
