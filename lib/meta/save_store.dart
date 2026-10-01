import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'meta_state.dart';

/// Local save for [MetaState]. Writes are queued so a slower older snapshot
/// cannot overwrite a newer one.
class SaveStore {
  SaveStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const String storageKey = 'backyard_barrage_meta_v1';

  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();

  Future<SharedPreferences> _instance() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<MetaState> load() async {
    final prefs = await _instance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return MetaState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MetaState.fromJson(decoded);
      }
      if (decoded is Map) {
        return MetaState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      return MetaState();
    }
    return MetaState();
  }

  Future<void> save(MetaState state) {
    final raw = jsonEncode(state.toJson());
    _queue = _queue.then((_) async {
      final prefs = await _instance();
      await prefs.setString(storageKey, raw);
    });
    return _queue;
  }
}
