import '../game/rival_type.dart';

/// Winter snowballs or summer water balloons. Same rules, different art.
enum Season {
  winter,
  summer;

  String get label => switch (this) {
    Season.winter => 'Winter',
    Season.summer => 'Summer',
  };

  /// Seasons the player can pick. Summer is off until its art is redone to
  /// match winter; flip it back on here and the toggles return.
  static const List<Season> playable = [Season.winter];

  /// Whether the player gets a season choice at all.
  static bool get choosable => playable.length > 1;

  /// This season if it is playable, otherwise the first playable one. Old
  /// saves on a switched-off season load into this.
  Season get orPlayable => playable.contains(this) ? this : playable.first;

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
    Season.winter => 'projectiles/snowball.png',
    Season.summer => 'projectiles/water_balloon_draft.png',
  };

  static String impact(Season season) => switch (season) {
    Season.winter => 'vfx/impact_snow_draft.png',
    Season.summer => 'vfx/impact_splash_draft.png',
  };

  /// Player-winter poses: Ethan's 3D kid (`characters/player/ethan3d/`).
  ///
  /// One wind-up pose seen from profile through 3/4 front, all facing the
  /// rivals. Straight across (and idle, throw, hit, KO, which have no
  /// approved frames yet) is `aim_01`. Aiming up-screen turns away from the
  /// camera, so it holds the profile; aiming down-screen turns toward the
  /// camera through `aim_02` to the 3/4 front. Walking runs [walkCycle].
  static const ethan3dDir = 'characters/player/ethan3d/';

  /// Each crew kid's art: Kid 1 the blue kid, Kid 2 the green girl, Kid 3
  /// the red boy. Same frames, size, and foot line in every folder.
  static const crewDirs = [
    ethan3dDir,
    'characters/player/team_green/',
    'characters/player/team_red/',
  ];

  static String crewDir(int kid) => crewDirs[kid.clamp(0, crewDirs.length - 1)];

  static const _playerWinterAim = {
    'turn_30l': 'kid_aim_away_01_512.png',
    'turn_15l': 'kid_aim_away_00_512.png',
    'charge': 'aim_01_512.png',
    'turn_15r': 'aim_02_512.png',
    'turn_30r': 'aim_03_34front_512.png',
    'idle': 'kid_idle_512.png',
    'walk': 'kid_run_00_512.png',
    'throw': 'kid_throw_follow_512.png',
    'hit': 'kid_hit_512.png',
    'ko': 'kid_ko_512.png',
    'pickup': 'kid_idle_512.png',
  };

  /// Frames that loop while the kid walks, or null for a single frame.
  static List<String>? walkCycle({
    required bool player,
    required Season season,
    int kid = 0,
  }) {
    if (!player || season != Season.winter) return null;
    return [
      for (final i in ['00', '01', '02', '03'])
        '${crewDir(kid)}kid_run_${i}_512.png',
    ];
  }

  /// Drawn size of the player's art relative to the 152px body box. The
  /// Ethan 3D renders leave headroom above the hat.
  static double playerDrawScale(Season season) =>
      season == Season.winter ? 1.15 : 1;

  /// True when the KO pose is an upright frame that has to be tipped over
  /// in code. Every current pack has a lying-down KO frame.
  static bool uprightKo({required bool player, required Season season}) =>
      false;

  /// Source square for a render, in pixels: left, top, side. Null for the
  /// 2D drafts, which fill their frame and stand on the bottom edge.
  ///
  /// Rival and Ethan 3D renders are 512² with the feet on y≈471 (941/1024).
  /// A square as tall as the feet line sits them on the bottom-center
  /// anchor. The widest frames lose a few pixels at the edges.
  static (double, double, double)? crop(String path) {
    if (path.startsWith(rivalDir) || crewDirs.any(path.startsWith)) {
      return (20.5, 0, 471);
    }
    return null;
  }

  static const rivalDir = 'characters/rivals/';

  /// Rival art for [type], or null when the type uses the 2D enemy drafts.
  ///
  /// Both rivals charge on their windup, snowball raised, in the same look
  /// as their throw. Their `aim_*` frames are a smoother sculpt and are not
  /// drawn. The ghost windup is the v1 frame from `characters/enemy/ghost/`,
  /// rescaled to the v2 framing.
  static String? rivalPose(RivalType type, String pose) {
    final (folder, frame) = switch (type) {
      RivalType.rusher => (
        'rusher',
        switch (pose) {
          'charge' ||
          'turn_30l' ||
          'turn_15l' ||
          'turn_15r' ||
          'turn_30r' => 'windup',
          'walk' => 'walk_00',
          'pickup' => 'idle',
          _ => pose,
        },
      ),
      RivalType.snowGhost => (
        'ghost',
        switch (pose) {
          'charge' ||
          'turn_30l' ||
          'turn_15l' ||
          'turn_15r' ||
          'turn_30r' => 'windup',
          'walk' => 'walk_00',
          'pickup' => 'idle',
          _ => pose,
        },
      ),
      RivalType.frostKid => (
        'frostkid',
        switch (pose) {
          'charge' ||
          'turn_30l' ||
          'turn_15l' ||
          'turn_15r' ||
          'turn_30r' => 'windup',
          'walk' => 'walk_00',
          'pickup' => 'idle',
          _ => pose,
        },
      ),
    };
    return '$rivalDir$folder/${folder}_${frame}_draft.png';
  }

  /// Drawn size of a rival's art relative to its 152px body box. The renders
  /// leave headroom above the hat, so they draw a little larger to stand
  /// about as tall as the player kid. Hit circles do not change.
  /// The snowman is the plain rival and draws smallest; the rusher (the
  /// brute) draws about 10% taller than it, and the frost kid in between.
  static double rivalDrawScale(RivalType type) => switch (type) {
    RivalType.snowGhost => 1.0,
    RivalType.frostKid => 1.03,
    RivalType.rusher => 1.15,
  };

  /// Frames a rival loops while it walks on or steps.
  static List<String> rivalWalkCycle(RivalType type) {
    final folder = switch (type) {
      RivalType.snowGhost => 'ghost',
      RivalType.rusher => 'rusher',
      RivalType.frostKid => 'frostkid',
    };
    return [
      for (final i in ['00', '01', '02', '03'])
        '$rivalDir$folder/${folder}_walk_${i}_draft.png',
    ];
  }

  static String pose({
    required bool player,
    required Season season,
    required String pose,
    int kid = 0,
  }) {
    if (player && season == Season.winter) {
      final aimed = _playerWinterAim[pose];
      if (aimed != null) return '${crewDir(kid)}$aimed';
    }
    final who = player ? 'player' : 'enemy';
    return 'characters/$who/${who}_${pose}_${season.name}_draft.png';
  }
}
