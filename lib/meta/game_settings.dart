import 'difficulty.dart';

/// SFX, music, haptics, and difficulty. Stored beside the meta save.
///
/// Older saves also carry a `modernUi` flag from when a classic wood kit
/// existed. It is ignored on load and no longer written.
class GameSettings {
  const GameSettings({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.difficulty = Difficulty.normal,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  /// Missing saves stay on Normal.
  final Difficulty difficulty;

  GameSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    Difficulty? difficulty,
  }) {
    return GameSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, Object> toJson() => {
    'sfx': sfxEnabled,
    'music': musicEnabled,
    'haptics': hapticsEnabled,
    'difficulty': difficulty.name,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      sfxEnabled: _asBool(json['sfx']),
      musicEnabled: _asBool(json['music']),
      hapticsEnabled: _asBool(json['haptics']),
      difficulty: DifficultyTuning.parse(json['difficulty']),
    );
  }

  static bool _asBool(Object? value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }
}
