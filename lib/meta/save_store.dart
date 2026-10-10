import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meta_state.dart';
import 'player_save.dart';

/// Local save for [PlayerSave]. Writes are queued so a slower older snapshot
/// cannot overwrite a newer one.
///
/// The storage key stays `backyard_barrage_meta_v1`. A document without
/// `arcade` / `campaign` is the old single wallet and loads as Arcade.
class SaveStore {
  SaveStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const String storageKey = 'backyard_barrage_meta_v1';

  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();
  PlayerSave? _profile;

  Future<SharedPreferences> _instance() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<PlayerSave> load() {
    return _queue.then((_) async {
      return _profile ??= await _read();
    });
  }

  /// Write [active] into its mode slot. The other mode's coins and skills stay.
  ///
  /// When [active] is the cached profile's own wallet (the game plays on
  /// the object the menu loaded), the write serializes it as it is when the
  /// write runs. Copying the call-time snapshot back onto it would undo
  /// anything earned while the write waited in the queue.
  Future<void> save(MetaState active) {
    final snap = WalletSnap.from(active);
    return _enqueue(() async {
      final profile = _profile ??= await _read();
      final slot = profile.wallet(snap.mode, snap.difficulty);
      if (identical(slot, active)) {
        profile
          ..season = active.season
          ..mode = active.mode;
      } else {
        profile.apply(snap);
      }
      await _write(profile);
    });
  }

  /// Write both wallets and the shared season. Used by the home screen.
  Future<void> saveProfile(PlayerSave profile) {
    return _enqueue(() async {
      _profile = profile;
      await _write(profile);
    });
  }

  /// Runs [job] after every earlier write. A write that fails is logged and
  /// skipped; it never blocks the writes queued after it.
  Future<void> _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object error) {
      debugPrint('SaveStore: write failed: $error');
    });
    return _queue;
  }

  /// Makes the next write throw, to test that the queue recovers.
  @visibleForTesting
  bool debugFailNextWrite = false;

  /// Where an unreadable save is copied before a fresh one replaces it.
  static const String corruptKey = '${storageKey}_unreadable';

  Future<void> _write(PlayerSave profile) async {
    if (debugFailNextWrite) {
      debugFailNextWrite = false;
      throw StateError('test write failure');
    }
    final prefs = await _instance();
    await prefs.setString(storageKey, jsonEncode(profile.toJson()));
  }

  Future<PlayerSave> _read() async {
    final prefs = await _instance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return PlayerSave();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PlayerSave.fromJson(decoded);
      }
      if (decoded is Map) {
        return PlayerSave.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      // Keep the unreadable save before the next write replaces it, so
      // progress can still be recovered by hand.
      debugPrint('SaveStore: unreadable save: $error');
      await prefs.setString(corruptKey, raw);
    }
    return PlayerSave();
  }
}
