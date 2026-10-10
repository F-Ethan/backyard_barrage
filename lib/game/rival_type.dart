import 'dart:math' as math;
import 'dart:ui' show Color;

import 'arena_grid.dart';

/// Kinds of rival. People vs snowmen: the snow crew is the rival side.
enum RivalType {
  /// The standard rival. Lobs on the difficulty timer and steps to lanes.
  snowGhost,

  /// The sniper. Stays on the back line, winds up longer with a glint at
  /// the hand, aims true, and re-aims once partway through the windup.
  /// Goes down to a single snowball on every difficulty.
  frostKid,

  /// Up close and fast. Holds the front line and throws quick, loose lobs.
  /// Drawn as a snowman with a red tint and glow until it gets its own art.
  rusher,
}

/// How one [RivalType] plays, on top of the difficulty and wave tuning.
class RivalProfile {
  const RivalProfile({
    this.gapScale = 1,
    this.windupScale = 1,
    this.jitterScale = 1,
    this.stepScale = 1,
    this.hpDelta = 0,
    this.holdColumn,
    this.glint = false,
    this.glintAt,
    this.aura,
    this.fixedHits,
    this.reaimAt,
  });

  /// Hits to put this rival down whatever the difficulty and wave. Null
  /// uses the difficulty's count plus [hpDelta].
  final int? fixedHits;

  /// Fraction of the windup at which this rival looks again and moves its
  /// aim to where the target stands then, once per throw. Null never
  /// re-aims, so stepping away during the windup dodges.
  final double? reaimAt;

  /// A colored tint and pulsing glow that marks this rival out from the
  /// snowmen it shares art with. Null draws the art as is.
  final Color? aura;

  /// Multiplier on the time between throws.
  final double gapScale;

  /// Multiplier on the charge pose before a release.
  final double windupScale;

  /// Multiplier on aim scatter (how often a lob lands short or long).
  final double jitterScale;

  /// Multiplier on step speed.
  final double stepScale;

  /// Added to the difficulty's hits-to-KO. Never below 1.
  final int hpDelta;

  /// Column this rival works back to and then stays on: it only changes
  /// rows (and steps back after a hit). Column 0 is the front line nearest
  /// the players; the last column is behind the fort. Null keeps the
  /// standard lane stepping.
  final int? holdColumn;

  /// Show a glint at the hand while winding up, so a long-range throw is
  /// readable before it leaves.
  final bool glint;

  /// Where the glint sits on the windup art, from the feet, as a fraction
  /// of the art square. Null uses the throwing hand.
  final (double, double)? glintAt;

  static RivalProfile of(RivalType type) => switch (type) {
    RivalType.snowGhost => const RivalProfile(),
    RivalType.frostKid => const RivalProfile(
      gapScale: 1.3,
      windupScale: 1.25,
      jitterScale: 0.15,
      fixedHits: 1,
      reaimAt: 0.6,
      holdColumn: ArenaGrid.columnsPerSide - 1,
      glint: true,
      // The snowball held up behind the head in frostkid_windup.
      glintAt: (0.209, -0.706),
    ),
    RivalType.rusher => const RivalProfile(
      gapScale: 0.55,
      windupScale: 0.55,
      jitterScale: 2.2,
      stepScale: 1.6,
      holdColumn: 0,
      aura: Color(0xFFFF4D4D),
    ),
  };

  int hitsToKo(int base) {
    final fixed = fixedHits;
    if (fixed != null) return fixed;
    final hits = base + hpDelta;
    return hits < 1 ? 1 : hits;
  }
}

/// Which rivals make up a wave.
///
/// Snowmen in the even slots, a random special in each odd slot.
class RivalRoster {
  const RivalRoster._();

  /// Rivals that can fill the in-between slots.
  static const specials = [RivalType.frostKid, RivalType.rusher];

  /// The line-up alternates: snowman, a random special, snowman, a random
  /// special... So one rival is always a snowman, the second is a surprise,
  /// the third is a snowman again, and every new slot changes the mix. The
  /// specials are re-rolled each wave.
  static List<RivalType> forWave({
    required int count,
    required math.Random rng,
  }) => [
    for (var i = 0; i < count; i++)
      i.isEven ? RivalType.snowGhost : specials[rng.nextInt(specials.length)],
  ];
}
