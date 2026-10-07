/// Winter snowballs or summer water balloons. Same rules, different art.
enum Season {
  winter,
  summer;

  String get label => switch (this) {
    Season.winter => 'Winter',
    Season.summer => 'Summer',
  };

  static Season? tryParse(String? name) {
    for (final season in Season.values) {
      if (season.name == name) return season;
    }
    return null;
  }
}

/// Asset paths relative to `assets/images/`.
class SeasonAssets {
  const SeasonAssets._();

  static const poseNames = [
    'idle',
    'walk',
    'charge',
    'throw',
    'hit',
    'ko',
    'pickup',
    'turn_30l',
    'turn_15l',
    'turn_15r',
    'turn_30r',
  ];

  static String background(Season season) => switch (season) {
    Season.winter => 'world/backyard_bg_winter_draft.png',
    Season.summer => 'world/backyard_bg_summer_draft.png',
  };

  static String projectile(Season season) => switch (season) {
    Season.winter => 'projectiles/snowball_draft.png',
    Season.summer => 'projectiles/water_balloon_draft.png',
  };

  static String impact(Season season) => switch (season) {
    Season.winter => 'vfx/impact_snow_draft.png',
    Season.summer => 'vfx/impact_splash_draft.png',
  };

  /// Player-winter aim sweep: 30l, 15l, sheet charge, 15r, 30r.
  ///
  /// Center is the sheet-matched charge (`from_sheet`), not the hero still
  /// `player_charge_winter_3d_v1.png`. Throw stays on the 2D draft.
  static const _playerWinterAim = {
    'turn_30l': 'characters/player/player_turn_30l_winter_3d_v1.png',
    'turn_15l': 'characters/player/player_turn_15l_winter_3d_v1.png',
    'charge': 'characters/player/player_charge_winter_3d_from_sheet.png',
    'turn_15r': 'characters/player/player_turn_15r_winter_3d_v1.png',
    'turn_30r': 'characters/player/player_turn_30r_winter_3d_v1.png',
  };

  static String pose({
    required bool player,
    required Season season,
    required String pose,
  }) {
    if (player && season == Season.winter) {
      final aimed = _playerWinterAim[pose];
      if (aimed != null) return aimed;
    }
    final who = player ? 'player' : 'enemy';
    return 'characters/$who/${who}_${pose}_${season.name}_draft.png';
  }
}
