import 'dart:math' as math;

/// What each skill rank does. The hand-tuned ranks come from tables; ranks
/// past the table keep going on a slower curve with a floor or a cap, so
/// a long run can keep loading up without breaking the fight.
///
/// Pure so the shop copy, the game, and tests agree.
abstract final class SkillEffects {
  static const List<double> poiseTable = [1, 0.82, 0.66, 0.52, 0.40];
  static const List<double> pressureTable = [1, 1.25, 1.55, 1.9, 2.3];
  static const List<double> aimTable = [1, 0.72, 0.48, 0.28];
  static const List<double> gapTable = [1, 0.84, 0.68, 0.52];
  static const List<double> chargeTable = [1, 0.86, 0.72, 0.58];
  static const List<double> blastTable = [1, 1.2, 1.45, 1.75, 2.05];

  /// Your stun lock, as a share of the base. ×0.85 a rank past the table.
  static double poise(int rank) => _shrink(poiseTable, rank, 0.85, 0.1);

  /// Rival stun lock multiplier. +0.35 a rank past the table, up to 6×.
  static double pressure(int rank) => _grow(pressureTable, rank, 0.35, 6);

  /// Teammate aim scatter. ×0.7 a rank past the table.
  static double aim(int rank) => _shrink(aimTable, rank, 0.7, 0.03);

  /// Teammate wait between throws. ×0.88 a rank past the table.
  static double gap(int rank) => _shrink(gapTable, rank, 0.88, 0.2);

  /// Teammate charge. ×0.88 a rank past the table.
  static double charge(int rank) => _shrink(chargeTable, rank, 0.88, 0.2);

  /// Snowball hit radius multiplier. +0.25 a rank past the table, up to 4×.
  static double blast(int rank) => _grow(blastTable, rank, 0.25, 4);

  /// Hits a wave each kid's shield blocks.
  static int shield(int rank) => math.min(math.max(rank, 0), 20);

  /// Fort HP on top of the stage. +4 a rank.
  static int fortHp(int rank) => 4 * math.max(rank, 0);

  /// Hits from the player's own throw. Odd ranks past 4 add one.
  static int manualHits(int rank) {
    if (rank <= 0) return 1;
    if (rank == 1) return 2;
    if (rank <= 4) return 3;
    return 3 + (rank - 3) ~/ 2;
  }

  /// Hits from teammate bots. Ranks 3 and 4, then even ranks past 4.
  static int botHits(int rank) {
    if (rank < 3) return 1;
    if (rank == 3) return 2;
    return 3 + (rank - 4) ~/ 2;
  }

  /// Seconds to a full player charge (before difficulty). Rank 0 is 3s and
  /// rank 5 is 1.9s; past 5 it keeps shrinking ×0.92 a rank, down to 0.8s.
  static double chargeSeconds(int throwRank) {
    final rank = math.max(throwRank, 0);
    if (rank <= 5) return math.max(1.7, 3 - rank * 0.22);
    return math.max(0.8, 1.9 * math.pow(0.92, rank - 5));
  }

  /// Snowball speed. Stops at rank 5 so lob ranges stay on the yard.
  static double projectileSpeed(int throwRank) =>
      1 + math.min(math.max(throwRank, 0), 5) * 0.07;

  static double _shrink(
    List<double> table,
    int rank,
    double factor,
    double floor,
  ) {
    if (rank <= 0) return table.first;
    if (rank < table.length) return table[rank];
    final past = rank - (table.length - 1);
    return math.max(floor, table.last * math.pow(factor, past));
  }

  static double _grow(List<double> table, int rank, double step, double cap) {
    if (rank <= 0) return table.first;
    if (rank < table.length) return table[rank];
    final past = rank - (table.length - 1);
    return math.min(cap, table.last + step * past);
  }
}
