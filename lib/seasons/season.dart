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

  /// Player-winter poses. Every one is from the 3D pack so the kid does
  /// not switch art styles between standing, walking, and charging.
  ///
  /// The aim sweep is 30l, 15l, sheet charge, 15r, 30r. The center is the
  /// sheet-matched charge (`from_sheet`), not the hero still
  /// `player_charge_winter_3d_v1.png`. The pack has no idle, walk, throw,
  /// hit, or KO frames yet, so those reuse the sheet charge. KO tips it over
  /// in [KidComponent].
  static const _playerWinter3dCenter =
      'characters/player/player_charge_winter_3d_from_sheet.png';

  static const _playerWinterAim = {
    'turn_30l': 'characters/player/player_turn_30l_winter_3d_v1.png',
    'turn_15l': 'characters/player/player_turn_15l_winter_3d_v1.png',
    'charge': _playerWinter3dCenter,
    'turn_15r': 'characters/player/player_turn_15r_winter_3d_v1.png',
    'turn_30r': 'characters/player/player_turn_30r_winter_3d_v1.png',
    'idle': _playerWinter3dCenter,
    'walk': _playerWinter3dCenter,
    'throw': _playerWinter3dCenter,
    'hit': _playerWinter3dCenter,
    'ko': _playerWinter3dCenter,
    'pickup': _playerWinter3dCenter,
  };

  /// True when every pose for this side and season comes from the 3D pack.
  /// That pack has no lying-down KO frame.
  static bool uprightKo({required bool player, required Season season}) =>
      player && season == Season.winter;

  /// Source square inside a 1024² 3D frame, in pixels: left, top, side.
  ///
  /// Studio frames keep the kid at about 77% of the square with the boots
  /// about 12% above the bottom. The 2D drafts fill the frame and stand on
  /// the bottom edge. This crop (hat top at y≈118, boots at y≈909 on every
  /// 3D frame) puts the 3D kid on the same bottom-center anchor at the same
  /// height. Null for 2D drafts, which use the whole image.
  static (double, double, double)? crop(String path) {
    if (!path.contains('_3d_')) return null;
    return (116, 118, 792);
  }

  /// 3D player frames whose lead arm points screen-left, at the kid's own
  /// fort. The player faces right toward the rivals (`docs/TURN_YAWS.md`),
  /// so these draw mirrored. `15r` and `30r` already point right.
  static const _pointsLeft = {
    'characters/player/player_turn_30l_winter_3d_v1.png',
    'characters/player/player_turn_15l_winter_3d_v1.png',
    _playerWinter3dCenter,
  };

  /// True when [path] should draw flipped left-to-right.
  static bool mirror(String path) => _pointsLeft.contains(path);

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
