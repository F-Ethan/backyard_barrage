/// How hard the backyard fight is. Stored with the other device settings.
enum Difficulty { easy, normal, hard }

/// Knobs that change with [Difficulty]. Row lanes, charge anchors, and the
/// peak-of-arc fort clear stay the same on every mode.
class DifficultyTuning {
  const DifficultyTuning({
    required this.throwGapMin,
    required this.throwGapMax,
    required this.throwsPerStep,
    required this.playerMoveScale,
    required this.friendlyFortDamage,
    required this.enemyStepSpeed,
  });

  /// Seconds from one enemy throw to the next.
  final double throwGapMin;
  final double throwGapMax;

  /// One grid step after this many throws. Higher means less chasing.
  final int throwsPerStep;

  /// Multiplier on the player's walk cap. 1 matches snowball pace.
  final double playerMoveScale;

  /// When true, a player's own lob can chip the player fort.
  final bool friendlyFortDamage;

  /// Pixels per second for an enemy's single-cell step.
  final double enemyStepSpeed;

  static DifficultyTuning of(Difficulty difficulty, {int wave = 1}) {
    final steps = wave < 1 ? 0 : wave - 1;
    switch (difficulty) {
      case Difficulty.easy:
        final max = (4.6 - steps * 0.06).clamp(3.6, 4.6).toDouble();
        return DifficultyTuning(
          throwGapMin: 3,
          throwGapMax: max,
          throwsPerStep: 6,
          playerMoveScale: 1.12,
          friendlyFortDamage: false,
          enemyStepSpeed: 120,
        );
      case Difficulty.hard:
        final max = (1.5 - steps * 0.025).clamp(1.08, 1.5).toDouble();
        return DifficultyTuning(
          throwGapMin: 1,
          throwGapMax: max,
          throwsPerStep: 2,
          playerMoveScale: 0.88,
          friendlyFortDamage: true,
          enemyStepSpeed: 170,
        );
      case Difficulty.normal:
        final max = (3.0 - steps * 0.05).clamp(2.0, 3.0).toDouble();
        return DifficultyTuning(
          throwGapMin: 1.5,
          throwGapMax: max,
          throwsPerStep: 3,
          playerMoveScale: 1,
          friendlyFortDamage: false,
          enemyStepSpeed: 150,
        );
    }
  }

  double throwGap(double random01) {
    final t = random01.clamp(0.0, 1.0).toDouble();
    return throwGapMin + (throwGapMax - throwGapMin) * t;
  }

  static Difficulty parse(Object? raw) {
    if (raw is String) {
      for (final value in Difficulty.values) {
        if (value.name == raw) return value;
      }
    }
    return Difficulty.normal;
  }
}
