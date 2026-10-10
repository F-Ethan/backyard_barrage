import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

/// Settings blob next to [SaveStore]'s meta key in the same preferences file.
class SettingsStore {
  SettingsStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const String storageKey = 'backyard_barrage_settings_v1';

  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();

  Future<SharedPreferences> _instance() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<GameSettings> load() async {
    final prefs = await _instance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const GameSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GameSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return GameSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('SettingsStore: unreadable settings: $error');
    }
    return const GameSettings();
  }

  Future<void> save(GameSettings settings) {
    final raw = jsonEncode(settings.toJson());
    // A failed write is logged and skipped; it never blocks later writes.
    _queue = _queue
        .then((_) async {
          final prefs = await _instance();
          await prefs.setString(storageKey, raw);
        })
        .catchError((Object error) {
          debugPrint('SettingsStore: write failed: $error');
        });
    return _queue;
  }
}
