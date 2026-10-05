import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'ad_config.dart';
import 'remove_ads.dart';

/// Non-consumable purchase through the official `in_app_purchase` plugin.
///
/// [buy] only starts the sheet. Ownership arrives on [InAppPurchase.purchaseStream].
class StoreRemoveAdsCatalog implements RemoveAdsCatalog {
  StoreRemoveAdsCatalog({InAppPurchase? store}) : _store = store;

  final InAppPurchase? _store;
  InAppPurchase? _resolved;
  ProductDetails? _product;
  Completer<bool>? _restoreWaiter;
  Future<RemoveAdsRestore>? _restoreInFlight;
  var _listening = false;
  var _storeDown = false;

  @override
  void Function()? onOwned;

  @override
  void Function(String message)? onStatus;

  @override
  void start() {
    if (_listening) return;
    _listening = true;
    try {
      _billing.purchaseStream.listen(
        _onPurchases,
        onError: (_, _) {
          onStatus?.call(RemoveAdsCopy.restoreFailed);
          _finishRestore(false);
        },
      );
    } catch (_) {
      _storeDown = true;
    }
  }

  InAppPurchase get _billing {
    final existing = _resolved;
    if (existing != null) return existing;
    final injected = _store;
    if (injected != null) return _resolved = injected;
    return _resolved = InAppPurchase.instance;
  }

  @override
  Future<String?> loadPrice() async {
    if (_storeDown) return null;
    try {
      if (!await _billing.isAvailable()) return null;
      final response = await _billing.queryProductDetails({
        AdConfig.removeAdsProductId,
      });
      if (response.error != null) return null;
      if (response.notFoundIDs.contains(AdConfig.removeAdsProductId)) {
        return null;
      }
      for (final product in response.productDetails) {
        if (product.id != AdConfig.removeAdsProductId) continue;
        if (product.price.isEmpty) return null;
        _product = product;
        return product.price;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> buy() async {
    final product = _product;
    if (product == null || _storeDown) return false;
    try {
      return await _billing.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RemoveAdsRestore> restore() {
    final inFlight = _restoreInFlight;
    if (inFlight != null) return inFlight;
    final run = _restore();
    _restoreInFlight = run;
    return run.whenComplete(() {
      if (identical(_restoreInFlight, run)) _restoreInFlight = null;
    });
  }

  Future<RemoveAdsRestore> _restore() async {
    if (_storeDown) return RemoveAdsRestore.failed;
    final waiter = Completer<bool>();
    _restoreWaiter = waiter;
    try {
      await _billing.restorePurchases();
    } catch (_) {
      if (identical(_restoreWaiter, waiter)) _restoreWaiter = null;
      if (!waiter.isCompleted) waiter.complete(false);
      return RemoveAdsRestore.failed;
    }
    final found = await waiter.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        if (identical(_restoreWaiter, waiter)) _restoreWaiter = null;
        return false;
      },
    );
    return found ? RemoveAdsRestore.granted : RemoveAdsRestore.empty;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    if (purchases.isEmpty) {
      _finishRestore(false);
      return;
    }
    var granted = false;
    for (final purchase in purchases) {
      if (purchase.productID != AdConfig.removeAdsProductId) {
        unawaited(_complete(purchase));
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          granted = true;
          onOwned?.call();
          unawaited(_complete(purchase));
          break;
        case PurchaseStatus.error:
          onStatus?.call(RemoveAdsCopy.restoreFailed);
          unawaited(_complete(purchase));
          break;
        case PurchaseStatus.canceled:
          onStatus?.call(RemoveAdsCopy.canceled);
          unawaited(_complete(purchase));
          break;
        case PurchaseStatus.pending:
          onStatus?.call(RemoveAdsCopy.pending);
          break;
      }
    }
    if (granted) _finishRestore(true);
  }

  void _finishRestore(bool found) {
    final waiter = _restoreWaiter;
    if (waiter == null || waiter.isCompleted) return;
    _restoreWaiter = null;
    waiter.complete(found);
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    if (purchase.status == PurchaseStatus.pending) return;
    try {
      await _billing.completePurchase(purchase);
    } catch (_) {}
  }
}
