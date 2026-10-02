/// SFX, music, haptics, and which UI kit is on screen. Stored beside the meta save.
class GameSettings {
  const GameSettings({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.modernUi = true,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  /// Modern kit when true, classic wood kit when false. Missing saves stay modern.
  final bool modernUi;

  GameSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool? modernUi,
  }) {
    return GameSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      modernUi: modernUi ?? this.modernUi,
    );
  }

  Map<String, Object> toJson() => {
    'sfx': sfxEnabled,
    'music': musicEnabled,
    'haptics': hapticsEnabled,
    'modernUi': modernUi,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      sfxEnabled: _asBool(json['sfx']),
      musicEnabled: _asBool(json['music']),
      hapticsEnabled: _asBool(json['haptics']),
      modernUi: _asBool(json['modernUi']),
    );
  }

  static bool _asBool(Object? value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }
}
