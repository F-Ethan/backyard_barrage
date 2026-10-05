import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a restore call found. A failed store must not look like "not owned".
enum RemoveAdsRestore { granted, empty, failed }

/// Copy shown in Settings. Kept here so the store and the tests share it.
class RemoveAdsCopy {
  const RemoveAdsCopy._();

  static const unavailable = "Remove Ads isn't in the store right now.";
  static const restoreFailed = "Purchases can't be restored right now.";
  static const restoreEmpty = 'No Remove Ads purchase was found.';
  static const canceled = 'Purchase canceled.';
  static const pending = 'The purchase is still pending.';
}

/// StoreKit / Play Billing, or a fake in tests. No plugin import in this file.
abstract class RemoveAdsCatalog {
  /// Fires when a purchase or restore grants the product.
  void Function()? onOwned;

  /// A short note for a cancel, a pending charge, or a store error.
  void Function(String message)? onStatus;

  /// Listen to the store once [onOwned] and [onStatus] are set.
  void start() {}

  /// Localized price from the store, or null when the product is missing.
  Future<String?> loadPrice();

  /// Starts the non-consumable purchase. The result arrives through [onOwned].
  Future<bool> buy();

  /// Asks the store to restore this product.
  Future<RemoveAdsRestore> restore();
}

/// Used on web and in widget tests that never open a store.
class UnavailableRemoveAdsCatalog implements RemoveAdsCatalog {
  @override
  void Function()? onOwned;

  @override
  void Function(String message)? onStatus;

  @override
  void start() {}

  @override
  Future<String?> loadPrice() async => null;

  @override
  Future<bool> buy() async => false;

  @override
  Future<RemoveAdsRestore> restore() async => RemoveAdsRestore.failed;
}

/// Local entitlement for the Remove Ads product.
///
/// The bool is its own preference, so a run wipe does not bring ads back.
/// A failed or empty restore never clears it: offline play must keep the
/// purchase, and a later refund is not detected on device.
class RemoveAdsController extends ChangeNotifier {
  RemoveAdsController({
    RemoveAdsCatalog? catalog,
    SharedPreferences? preferences,
  }) : _catalog = catalog ?? UnavailableRemoveAdsCatalog(),
       _preferences = preferences {
    _catalog.onOwned = () {
      _ownedWrite = _markOwned();
    };
    _catalog.onStatus = _setNote;
    _catalog.start();
  }

  /// Separate from the meta save. Resetting a run must not clear this.
  static const storageKey = 'backyard_barrage_remove_ads_v1';

  final RemoveAdsCatalog _catalog;
  SharedPreferences? _preferences;
  Future<void>? _preparing;
  Future<void> _ownedWrite = Future<void>.value();
  var _disposed = false;

  bool owned = false;
  String? priceLabel;
  bool productReady = false;
  String? note;

  Future<void> prepare() {
    return _preparing ??= _prepare();
  }

  Future<void> _prepare() async {
    final prefs = await _prefs();
    if (prefs?.getBool(storageKey) ?? false) {
      owned = true;
    }
    try {
      final price = await _catalog.loadPrice();
      priceLabel = (price == null || price.isEmpty) ? null : price;
      productReady = priceLabel != null;
    } catch (_) {
      priceLabel = null;
      productReady = false;
    }
    if (owned) {
      // Confirm with the store, but do not wait on it and do not revoke.
      unawaited(restore(quiet: true));
    } else {
      await restore(quiet: true);
    }
    await _ownedWrite;
    _notify();
  }

  Future<void> buy() async {
    if (owned) return;
    note = null;
    if (!productReady) {
      note = RemoveAdsCopy.unavailable;
      _notify();
      return;
    }
    _notify();
    try {
      final sent = await _catalog.buy();
      await _ownedWrite;
      if (!sent && !owned) {
        note = RemoveAdsCopy.unavailable;
      }
    } catch (_) {
      if (!owned) note = RemoveAdsCopy.unavailable;
    }
    _notify();
  }

  Future<void> restore({bool quiet = false}) async {
    if (!quiet) {
      note = null;
      _notify();
    }
    RemoveAdsRestore result;
    try {
      result = await _catalog.restore();
      await _ownedWrite;
    } catch (_) {
      result = RemoveAdsRestore.failed;
    }
    if (!quiet && !owned) {
      note = switch (result) {
        RemoveAdsRestore.granted => null,
        RemoveAdsRestore.empty => RemoveAdsCopy.restoreEmpty,
        RemoveAdsRestore.failed => RemoveAdsCopy.restoreFailed,
      };
    }
    _notify();
  }

  Future<void> _markOwned() async {
    owned = true;
    note = null;
    try {
      final prefs = await _prefs();
      await prefs?.setBool(storageKey, true);
    } catch (_) {}
    _notify();
  }

  void _setNote(String message) {
    note = message;
    _notify();
  }

  Future<SharedPreferences?> _prefs() async {
    if (_preferences != null) return _preferences;
    try {
      return _preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
