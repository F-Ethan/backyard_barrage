import 'dart:convert';

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
  Future<void> save(MetaState active) {
    final snap = WalletSnap.from(active);
    _queue = _queue.then((_) async {
      final profile = _profile ??= await _read();
      profile.apply(snap);
      await _write(profile);
    });
    return _queue;
  }

  /// Write both wallets and the shared season. Used by the home screen.
  Future<void> saveProfile(PlayerSave profile) {
    _queue = _queue.then((_) async {
      _profile = profile;
      await _write(profile);
    });
    return _queue;
  }

  Future<void> _write(PlayerSave profile) async {
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
    } on FormatException {
      return PlayerSave();
    }
    return PlayerSave();
  }
}
