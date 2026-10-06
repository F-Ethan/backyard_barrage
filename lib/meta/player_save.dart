import '../seasons/season.dart';
import 'meta_state.dart';
import 'play_mode.dart';

/// Both mode wallets plus the shared season and the last mode played.
///
/// An older flat [MetaState] document loads into [arcade]. Campaign starts
/// empty so those coins and skills are not lost and do not leak across.
class PlayerSave {
  PlayerSave({
    this.season = Season.winter,
    this.mode = PlayMode.arcade,
    MetaState? arcade,
    MetaState? campaign,
  }) : arcade = arcade ?? MetaState(mode: PlayMode.arcade, season: season),
       campaign =
           campaign ?? MetaState(mode: PlayMode.campaign, season: season);

  /// Skin for the yard and the home screen. Both modes use it.
  Season season;

  /// Last mode the player started. Home still offers both.
  PlayMode mode;

  final MetaState arcade;
  final MetaState campaign;

  MetaState wallet(PlayMode which) =>
      which == PlayMode.campaign ? campaign : arcade;

  MetaState get active => wallet(mode);

  /// Copy one mode's coins, skills, and best wave. The other wallet stays.
  void apply(WalletSnap snap) {
    season = snap.season;
    mode = snap.mode;
    final slot = wallet(snap.mode);
    slot
      ..coins = snap.coins
      ..bestWave = snap.bestWave
      ..season = snap.season
      ..mode = snap.mode
      ..replaceSkills(snap.skills);
    arcade.season = season;
    campaign.season = season;
  }

  Map<String, Object> toJson() => {
    'v': 2,
    'season': season.name,
    'mode': mode.name,
    'arcade': arcade.toJson(),
    'campaign': campaign.toJson(),
  };

  factory PlayerSave.fromJson(Map<String, dynamic> json) {
    final nested = json.containsKey('arcade') || json.containsKey('campaign');
    if (!nested) {
      final legacy = MetaState.fromJson(json)..mode = PlayMode.arcade;
      return PlayerSave(
        season: legacy.season,
        mode: PlayMode.arcade,
        arcade: legacy,
        campaign: MetaState(mode: PlayMode.campaign, season: legacy.season),
      );
    }
    final season = Season.tryParse(json['season'] as String?) ?? Season.winter;
    final mode = PlayMode.tryParse(json['mode'] as String?) ?? PlayMode.arcade;
    return PlayerSave(
      season: season,
      mode: mode,
      arcade: _wallet(json['arcade'], PlayMode.arcade, season),
      campaign: _wallet(json['campaign'], PlayMode.campaign, season),
    );
  }

  static MetaState _wallet(Object? raw, PlayMode mode, Season season) {
    final MetaState meta;
    if (raw is Map<String, dynamic>) {
      meta = MetaState.fromJson(raw);
    } else if (raw is Map) {
      meta = MetaState.fromJson(Map<String, dynamic>.from(raw));
    } else {
      meta = MetaState();
    }
    meta.mode = mode;
    meta.season = season;
    return meta;
  }
}

/// Fields copied at the moment of a save so a later edit cannot race it.
class WalletSnap {
  WalletSnap({
    required this.mode,
    required this.season,
    required this.coins,
    required this.bestWave,
    required this.skills,
  });

  factory WalletSnap.from(MetaState state) {
    return WalletSnap(
      mode: state.mode,
      season: state.season,
      coins: state.coins,
      bestWave: state.bestWave,
      skills: Set<String>.from(state.skills),
    );
  }

  final PlayMode mode;
  final Season season;
  final int coins;
  final int bestWave;
  final Set<String> skills;
}
