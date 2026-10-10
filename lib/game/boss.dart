import 'dart:math' as math;

import '../meta/difficulty.dart';

/// The two bosses. A boss closes every Arcade stage from wave 10.
enum BossType {
  /// Lobs magma balls and pushes a heat wave along its row.
  magma('Magmo', 'magma'),

  /// Throws giant snowballs and hops, crashing down so ice spikes burst up
  /// under the crew.
  ogre('Grumblefrost', 'ogre');

  const BossType(this.label, this.folder);

  /// Name on the health bar and the intro banner.
  final String label;

  /// Art folder and file prefix under `characters/bosses/`.
  final String folder;
}

/// When bosses come, how tough they are, and what they pay.
abstract final class BossRules {
  /// First boss wave. After this, the last wave of every stage.
  static const int firstWave = 10;

  /// Waves between bosses (one Arcade stage).
  static const int every = 5;

  static bool isBossWave(int wave) =>
      wave >= firstWave && (wave - firstWave) % every == 0;

  /// 1 for the first boss wave, 2 for the next, and so on.
  static int appearance(int wave) => (wave - firstWave) ~/ every + 1;

  /// Rivals walking on with the boss. The first boss comes alone; each one
  /// after brings one more.
  static int supportFor(int wave) => appearance(wave) - 1;

  /// Hits to put a boss down: 6 / 9 / 12 (Easy / Normal / Hard) the first
  /// time, then 25% more each time a boss comes back.
  static int hits(Difficulty difficulty, int appearance) {
    final base = switch (difficulty) {
      Difficulty.easy => 6,
      Difficulty.normal => 9,
      Difficulty.hard => 12,
    };
    return (base * math.pow(1.25, math.max(appearance, 1) - 1)).round();
  }

  /// A random boss, never the same as [last] twice in a row.
  static BossType pick(math.Random rng, {BossType? last}) {
    final pool = [
      for (final type in BossType.values)
        if (type != last) type,
    ];
    return pool[rng.nextInt(pool.length)];
  }

  /// Power-ups for knocking a boss out.
  static const int rewardItems = 3;

  /// A boss wave's clear bonus is this many times the normal one.
  static const int coinMultiplier = 3;

  /// How long the ground cracks before an ice spike bursts up. Long enough
  /// to step off it.
  static double spikeWarnSeconds(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 1.0,
    Difficulty.normal => 0.8,
    Difficulty.hard => 0.6,
  };

  /// Seconds the magma elemental leans back before the heat wave, glowing,
  /// with the wave's path marked on the ground.
  static const double waveWindupSeconds = 1.3;

  /// Seconds the ogre crouches, then hangs in the air, before it crashes.
  static const double hopCrouchSeconds = 0.6;
  static const double hopAirSeconds = 0.5;

  /// Peak of the ogre's hop, in pixels.
  static const double hopHeight = 70;

  /// Seconds between a boss's normal throws, and between its specials.
  static double throwGap(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 3.2,
    Difficulty.normal => 2.6,
    Difficulty.hard => 2.0,
  };

  static double specialGap(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 10,
    Difficulty.normal => 8.5,
    Difficulty.hard => 7,
  };
}

/// Image paths (under `assets/images/`) for the bosses and their attacks.
abstract final class BossArt {
  static String pose(BossType type, String name) =>
      'characters/bosses/${type.folder}/${type.folder}_$name.png';

  static List<String> walk(BossType type) => [
    for (final i in ['00', '01', '02', '03']) pose(type, 'walk_$i'),
  ];

  /// Frames only the special moves use.
  static List<String> specials(BossType type) => switch (type) {
    BossType.magma => [pose(type, 'wave_windup'), pose(type, 'wave_push')],
    BossType.ogre => [
      pose(type, 'hop_crouch'),
      pose(type, 'hop_air'),
      pose(type, 'crash'),
    ],
  };

  static const magmaBall = 'vfx/boss/magma_ball.png';
  static const magmaImpact = 'vfx/boss/magma_impact.png';
  static const fireWave = 'vfx/boss/fire_wave.png';
  static const shockwave = 'vfx/boss/shockwave_ring.png';
  static const iceSpikes = [
    'vfx/boss/ice_spike_00.png',
    'vfx/boss/ice_spike_01.png',
    'vfx/boss/ice_spike_02.png',
  ];

  static const _poses = ['idle', 'windup', 'throw', 'hit', 'ko'];

  /// Every boss image, for preloading and tests.
  static List<String> get all => [
    for (final type in BossType.values) ...[
      for (final name in _poses) pose(type, name),
      ...walk(type),
      ...specials(type),
    ],
    magmaBall,
    magmaImpact,
    fireWave,
    shockwave,
    ...iceSpikes,
  ];
}
