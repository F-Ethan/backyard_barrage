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
    this.leadKid = 0,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;

  /// Missing saves stay on Normal.
  final Difficulty difficulty;

  /// The kid you control when a wave starts (0 Mike, 1 Beth, 2 Ruben).
  /// Falls back to the first kid standing when that one is not in the crew
  /// or is down.
  final int leadKid;

  GameSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    Difficulty? difficulty,
    int? leadKid,
  }) {
    return GameSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      difficulty: difficulty ?? this.difficulty,
      leadKid: leadKid ?? this.leadKid,
    );
  }

  Map<String, Object> toJson() => {
    'sfx': sfxEnabled,
    'music': musicEnabled,
    'haptics': hapticsEnabled,
    'difficulty': difficulty.name,
    'leadKid': leadKid,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      sfxEnabled: _asBool(json['sfx']),
      musicEnabled: _asBool(json['music']),
      hapticsEnabled: _asBool(json['haptics']),
      difficulty: DifficultyTuning.parse(json['difficulty']),
      leadKid: switch (json['leadKid']) {
        final int kid when kid >= 0 && kid <= 2 => kid,
        _ => 0,
      },
    );
  }

  static bool _asBool(Object? value, {bool fallback = true}) {
    if (value is bool) return value;
    return fallback;
  }
}
