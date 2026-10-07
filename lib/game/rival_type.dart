import '../meta/difficulty.dart';
import 'arena_grid.dart';

/// Kinds of rival. People vs snowmen: the snow crew is the rival side.
enum RivalType {
  /// The standard rival. Lobs on the difficulty timer and steps to lanes.
  snowGhost,

  /// Long range. Hangs back behind the fort, winds up longer with a glint
  /// at the hand, and rarely misses the distance. One hit less to put down.
  frostKid,

  /// Up close. Holds the front line and throws quick, loose lobs.
  /// Stand-in art: the original 2D rival kid.
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
  });

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

  /// Column this rival works back to between throws. Column 0 is the front
  /// line nearest the players; the last column is behind the fort. Null
  /// keeps the standard lane stepping.
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
      jitterScale: 0.3,
      hpDelta: -1,
      holdColumn: ArenaGrid.columnsPerSide - 1,
      glint: true,
      // The snowball held up behind the head in frostkid_windup.
      glintAt: (0.209, -0.706),
    ),
    RivalType.rusher => const RivalProfile(
      gapScale: 0.7,
      windupScale: 0.7,
      jitterScale: 1.5,
      stepScale: 1.3,
      holdColumn: 0,
    ),
  };

  int hitsToKo(int base) {
    final hits = base + hpDelta;
    return hits < 1 ? 1 : hits;
  }
}

/// Which rivals make up a wave.
///
/// Slot 0 is always a snow ghost. Frost kids and rushers join from a wave
/// that depends on difficulty, and their share grows every couple of waves
/// after that. The head count caps (the yard holds five), but the mix keeps
/// shifting, so a long run keeps changing after the count stops.
class RivalRoster {
  const RivalRoster._();

  static int unlockWave(RivalType type, Difficulty difficulty) =>
      switch ((type, difficulty)) {
        (RivalType.snowGhost, _) => 1,
        (RivalType.frostKid, Difficulty.easy) => 4,
        (RivalType.frostKid, Difficulty.normal) => 3,
        (RivalType.frostKid, Difficulty.hard) => 2,
        (RivalType.rusher, Difficulty.easy) => 6,
        (RivalType.rusher, Difficulty.normal) => 5,
        (RivalType.rusher, Difficulty.hard) => 3,
      };

  static List<RivalType> forWave({
    required int wave,
    required int count,
    required Difficulty difficulty,
  }) {
    if (count <= 0) return const [];
    final specials = [
      for (final type in [RivalType.frostKid, RivalType.rusher])
        if (wave >= unlockWave(type, difficulty)) type,
    ];
    final lineup = List.filled(count, RivalType.snowGhost);
    if (specials.isEmpty) return lineup;
    final firstUnlock = unlockWave(specials.first, difficulty);
    final share = (1 + (wave - firstUnlock) ~/ 2).clamp(0, count - 1);
    // Fill from the back slots so the first rival stays a ghost.
    for (var i = 0; i < share; i++) {
      lineup[count - 1 - i] = specials[i % specials.length];
    }
    return lineup;
  }
}
