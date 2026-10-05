import '../game/combat_rules.dart';

/// How hard the backyard fight is. Stored with the other device settings.
enum Difficulty { easy, normal, hard }

/// Knobs that change with [Difficulty]. Row lanes, charge anchors, and the
/// peak-of-arc fort clear stay the same on every mode.
class DifficultyTuning {
  const DifficultyTuning({
    required this.throwGapMin,
    required this.throwGapMax,
    required this.throwsPerStep,
    required this.matchPlayerRow,
    required this.friendlyFortDamage,
    required this.enemyStepSpeed,
    required this.chargeVersusPlayer,
    required this.playerChargeTimeScale,
    required this.allyStunScale,
    this.chargeScale = 1,
  });

  /// Seconds from one enemy throw to the next.
  final double throwGapMin;
  final double throwGapMax;

  /// Throws between lane checks. 1 checks every throw. Easy uses 2.
  final int throwsPerStep;

  /// Hard steps onto the closest player's exact row. Easy and Normal
  /// hold still once a living player is already within one row.
  final bool matchPlayerRow;

  /// When true, a player's own lob can chip the player fort.
  final bool friendlyFortDamage;

  /// Pixels per second for an enemy's single-cell step.
  final double enemyStepSpeed;

  /// Bot charge hold divided by the player's full charge.
  ///
  /// 1 matches the player. Above 1 is slower than the player (Easy).
  /// Hard is below 1 and still follows the player's hold a little: about
  /// 0.45s at rank 0, down to the 0.3s floor as throw rank rises.
  final double chargeVersusPlayer;

  /// Extra multiplier on the windup. Teammate charge nodes use this so they
  /// shorten the Easy hold without falling into Hard's short window.
  final double chargeScale;

  /// Player charge time as a fraction of the throw-rank hold.
  /// Easy is 1/2 (2× speed). Normal is 2/3 (1.5× speed). Hard stays 1.
  final double playerChargeTimeScale;

  /// Ally stun as a fraction of the base lock.
  /// Easy is half. Normal is three quarters. Hard stays the full lock.
  final double allyStunScale;

  /// How long a bot holds the charge pose before releasing.
  ///
  /// Easy is longer than [playerCharge]. Normal matches it. Hard stays in
  /// the old short band, about 0.3–0.55s, so Hard still charges faster.
  double botChargeSeconds(double playerCharge) {
    final player = playerCharge < 0.2
        ? CombatRules.playerChargeSeconds(0)
        : playerCharge;
    final double seconds;
    if (chargeVersusPlayer < 1) {
      final window = player * chargeVersusPlayer;
      if (window < 0.3) {
        seconds = 0.3;
      } else if (window > 0.55) {
        seconds = 0.55;
      } else {
        seconds = window;
      }
    } else {
      seconds = player * chargeVersusPlayer;
    }
    final scaled = seconds * chargeScale;
    if (scaled < 0.2) return 0.2;
    return scaled;
  }

  /// Copy with shorter gaps and a shorter windup. Used for teammate bots.
  DifficultyTuning scaled({double gapScale = 1, double chargeScale = 1}) {
    return DifficultyTuning(
      throwGapMin: throwGapMin * gapScale,
      throwGapMax: throwGapMax * gapScale,
      throwsPerStep: throwsPerStep,
      matchPlayerRow: matchPlayerRow,
      friendlyFortDamage: friendlyFortDamage,
      enemyStepSpeed: enemyStepSpeed,
      chargeVersusPlayer: chargeVersusPlayer,
      playerChargeTimeScale: playerChargeTimeScale,
      allyStunScale: allyStunScale,
      chargeScale: this.chargeScale * chargeScale,
    );
  }

  static DifficultyTuning of(Difficulty difficulty, {int wave = 1}) {
    final steps = wave < 1 ? 0 : wave - 1;
    switch (difficulty) {
      case Difficulty.easy:
        // Longer than a full player charge, so the player finishes first.
        const versus = 1.5;
        final hold = CombatRules.playerChargeSeconds(0) * versus;
        final max = (hold + 1.1 - steps * 0.05)
            .clamp(hold, hold + 1.1)
            .toDouble();
        return DifficultyTuning(
          throwGapMin: hold,
          throwGapMax: max,
          throwsPerStep: 2,
          matchPlayerRow: false,
          friendlyFortDamage: false,
          enemyStepSpeed: 120,
          chargeVersusPlayer: versus,
          playerChargeTimeScale: 0.5,
          allyStunScale: 0.5,
        );
      case Difficulty.hard:
        final max = (1.5 - steps * 0.025).clamp(1.08, 1.5).toDouble();
        return DifficultyTuning(
          throwGapMin: 1,
          throwGapMax: max,
          throwsPerStep: 1,
          matchPlayerRow: true,
          friendlyFortDamage: true,
          enemyStepSpeed: 170,
          chargeVersusPlayer: 0.15,
          playerChargeTimeScale: 1,
          allyStunScale: 1,
        );
      case Difficulty.normal:
        // The cycle is at least one full player charge, so Normal bots
        // finish a charge when the player does.
        final hold = CombatRules.playerChargeSeconds(0);
        final max = (hold + 0.6 - steps * 0.04)
            .clamp(hold, hold + 0.6)
            .toDouble();
        return DifficultyTuning(
          throwGapMin: hold,
          throwGapMax: max,
          throwsPerStep: 1,
          matchPlayerRow: false,
          friendlyFortDamage: false,
          enemyStepSpeed: 150,
          chargeVersusPlayer: 1,
          playerChargeTimeScale: 2 / 3,
          allyStunScale: 0.75,
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
