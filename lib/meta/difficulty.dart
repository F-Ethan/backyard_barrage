import '../game/combat_rules.dart';

/// How hard the backyard fight is. Stored with the other device settings.
enum Difficulty {
  easy,
  normal,
  hard;

  String get label => switch (this) {
    Difficulty.easy => 'Easy',
    Difficulty.normal => 'Normal',
    Difficulty.hard => 'Hard',
  };

  /// One line for the home screen under the picker.
  String get summary => switch (this) {
    Difficulty.easy => 'Fast charge, short stuns, full aim guide.',
    Difficulty.normal => 'Quicker charge, aim path without the target ring.',
    Difficulty.hard =>
      'Full charge and stuns, no aim guide, rivals throw more.',
  };

  /// How much of the throw preview this mode draws while charging.
  AimPreview get aimPreview => switch (this) {
    Difficulty.easy => AimPreview.full,
    Difficulty.normal => AimPreview.path,
    Difficulty.hard => AimPreview.none,
  };
}

/// Throw preview levels. The aim arrow and charge glow always show.
enum AimPreview {
  /// Floor path, landing mark, and a ring on the rival the throw will hit.
  full,

  /// Floor path and landing mark. No target ring.
  path,

  /// No floor path.
  none,
}

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
    required this.enemyHitsToKo,
    this.chargeScale = 1,
    this.paceScale = 1,
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
  /// Rivals do not use this. Their brush-off and knockdown stay full length.
  final double allyStunScale;

  /// Hits to put a rival down. Easy is 1, Normal is 2, Hard is 3.
  /// Allies stay on [CombatRules.hitsToKo]. Wave 5 and later add
  /// [WavePlan.bonusHp] on top when the rival curve is on.
  final int enemyHitsToKo;

  /// Extra multiplier on a bot's windup. Throw gaps are already scaled by
  /// this when the tuning is built. 1 on waves 1–3. The strength rounds use
  /// [WavePlan.fasterThrowScale].
  final double paceScale;

  /// How long a bot holds the charge pose before releasing.
  ///
  /// [playerCharge] is the unscaled throw-rank hold, not the sped-up bar.
  /// Easy is 1.5× that hold (about 4.5s at rank 0). Normal matches it
  /// (about 3s). Hard stays in the old short band, about 0.3–0.55s.
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
    final scaled = seconds * chargeScale * paceScale;
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
      enemyHitsToKo: enemyHitsToKo,
      chargeScale: this.chargeScale * chargeScale,
      paceScale: paceScale,
    );
  }

  /// Rival pressure from [plan], on top of this difficulty's base.
  ///
  /// Faster throws shorten the windup and the gap. Quicker steps raise
  /// [enemyStepSpeed]. [WavePlan.bonusHp] is added to [enemyHitsToKo].
  /// Lane rules (how often they step, whether they match a row) stay put.
  DifficultyTuning withWavePlan(WavePlan plan) {
    final pace = plan.fasterThrows ? WavePlan.fasterThrowScale : 1.0;
    final step = plan.quickerSteps ? WavePlan.quickerStepScale : 1.0;
    return DifficultyTuning(
      throwGapMin: throwGapMin * pace,
      throwGapMax: throwGapMax * pace,
      throwsPerStep: throwsPerStep,
      matchPlayerRow: matchPlayerRow,
      friendlyFortDamage: friendlyFortDamage,
      enemyStepSpeed: enemyStepSpeed * step,
      chargeVersusPlayer: chargeVersusPlayer,
      playerChargeTimeScale: playerChargeTimeScale,
      allyStunScale: allyStunScale,
      enemyHitsToKo: enemyHitsToKo + plan.bonusHp,
      chargeScale: chargeScale,
      paceScale: paceScale * pace,
    );
  }

  static DifficultyTuning of(
    Difficulty difficulty, {
    int wave = 1,
    bool rivalCurve = false,
  }) {
    final steps = wave < 1 ? 0 : wave - 1;
    final DifficultyTuning base;
    switch (difficulty) {
      case Difficulty.easy:
        // Longer than a full player charge, so the player finishes first.
        const versus = 1.5;
        final hold = CombatRules.playerChargeSeconds(0) * versus;
        final max = (hold + 1.1 - steps * 0.05)
            .clamp(hold, hold + 1.1)
            .toDouble();
        base = DifficultyTuning(
          throwGapMin: hold,
          throwGapMax: max,
          throwsPerStep: 2,
          matchPlayerRow: false,
          friendlyFortDamage: false,
          enemyStepSpeed: 120,
          chargeVersusPlayer: versus,
          playerChargeTimeScale: 0.5,
          allyStunScale: 0.5,
          enemyHitsToKo: 1,
        );
      case Difficulty.hard:
        final max = (1.5 - steps * 0.025).clamp(1.08, 1.5).toDouble();
        base = DifficultyTuning(
          throwGapMin: 1,
          throwGapMax: max,
          throwsPerStep: 1,
          matchPlayerRow: true,
          friendlyFortDamage: true,
          enemyStepSpeed: 170,
          chargeVersusPlayer: 0.15,
          playerChargeTimeScale: 1,
          allyStunScale: 1,
          enemyHitsToKo: 3,
        );
      case Difficulty.normal:
        // The cycle is at least one full player charge, so Normal bots
        // finish a charge when the player does.
        final hold = CombatRules.playerChargeSeconds(0);
        final max = (hold + 0.6 - steps * 0.04)
            .clamp(hold, hold + 0.6)
            .toDouble();
        base = DifficultyTuning(
          throwGapMin: hold,
          throwGapMax: max,
          throwsPerStep: 1,
          matchPlayerRow: false,
          friendlyFortDamage: false,
          enemyStepSpeed: 150,
          chargeVersusPlayer: 1,
          playerChargeTimeScale: 2 / 3,
          allyStunScale: 0.75,
          enemyHitsToKo: 2,
        );
    }
    if (!rivalCurve) return base;
    return base.withWavePlan(WavePlan.forWave(wave));
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
