import 'difficulty.dart';

/// SFX, music, haptics, UI kit, and difficulty. Stored beside the meta save.
class GameSettings {
  const GameSettings({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.modernUi = true,
    this.difficulty = Difficulty.normal,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  /// Modern kit when true, classic wood kit when false. Missing saves stay modern.
  final bool modernUi;

  /// Missing saves stay on Normal.
  final Difficulty difficulty;

  GameSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool? modernUi,
    Difficulty? difficulty,
  }) {
    return GameSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      modernUi: modernUi ?? this.modernUi,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, Object> toJson() => {
    'sfx': sfxEnabled,
    'music': musicEnabled,
    'haptics': hapticsEnabled,
    'modernUi': modernUi,
    'difficulty': difficulty.name,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      sfxEnabled: _asBool(json['sfx']),
      musicEnabled: _asBool(json['music']),
      hapticsEnabled: _asBool(json['haptics']),
      modernUi: _asBool(json['modernUi']),
      difficulty: DifficultyTuning.parse(json['difficulty']),
    );
  }

  static bool _asBool(Object? value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }
}
