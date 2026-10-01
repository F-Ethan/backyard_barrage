/// SFX, music, and haptics. Stored beside the meta save.
class GameSettings {
  const GameSettings({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  GameSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
  }) {
    return GameSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  Map<String, Object> toJson() => {
    'sfx': sfxEnabled,
    'music': musicEnabled,
    'haptics': hapticsEnabled,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      sfxEnabled: _asBool(json['sfx']),
      musicEnabled: _asBool(json['music']),
      hapticsEnabled: _asBool(json['haptics']),
    );
  }

  static bool _asBool(Object? value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }
}
