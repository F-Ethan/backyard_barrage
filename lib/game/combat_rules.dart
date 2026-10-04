import 'package:flame/extensions.dart';

import 'throw_physics.dart';

enum RoundOutcome { ongoing, waveClear, defeat }

/// What one hit does to a kid who is still in the fight.
class HitResolution {
  const HitResolution({
    required this.hp,
    required this.lockSeconds,
    required this.fragile,
    required this.knockdown,
    required this.knockedOut,
  });

  final int hp;
  final double lockSeconds;
  final bool fragile;

  /// Enemy second hit: slumped, then back on their feet.
  final bool knockdown;
  final bool knockedOut;
}

/// Wave size, fort cover, and upgrade scaling. Pure so tests can lock it.
class CombatRules {
  const CombatRules._();

  /// Snowballs to put a rival down for good. An ally can go out sooner if
  /// they are hit again while the first hit's stun is still up.
  static const int hitsToKo = 3;

  /// Enemy hit 1. A short flinch; they cannot throw through it.
  static const double enemyBrushOffSeconds = 1;

  /// Enemy hit 2. Down, then back up. Longer than the brush-off, not a KO.
  static const double enemyKnockdownSeconds = 1.8;

  /// Ally hit 1. Cannot move or throw. A hit during this window KOs.
  /// Half of the previous 5.625s lock.
  static const double allyStunSeconds = 7.5 * 3 / 8;

  static int enemyCountForWave(int wave) {
    if (wave <= 1) return 2;
    return 3;
  }

  /// Fort HP regenerates to this value at the start of every wave.
  static int fortMaxHp(int stage) {
    return switch (_clampInt(stage, 1, 3)) {
      1 => 6,
      2 => 10,
      _ => 14,
    };
  }

  /// Seconds to reach a full player charge. Rank 0 is about 3 seconds.
  /// Throw-speed ranks shorten it; a full hold stays deliberate.
  static double playerChargeSeconds(int throwRank) {
    final rank = _clampInt(throwRank, 0, 5);
    final seconds = 3 - rank * 0.22;
    if (seconds < 1.7) return 1.7;
    return seconds;
  }

  static double projectileSpeedScale(int throwRank) {
    final rank = _clampInt(throwRank, 0, 5);
    return 1 + rank * 0.07;
  }

  /// Aim error in radians. Higher waves tighten it. The error scales how far
  /// an enemy lob lands short or long inside the throw lane.
  static double enemyAimJitterRadians(int wave) {
    final steps = wave < 1 ? 0 : wave - 1;
    final jitter = 0.38 - steps * 0.045;
    if (jitter < 0.08) return 0.08;
    return jitter.toDouble();
  }

  static RoundOutcome roundOutcome({
    required int livingPlayers,
    required int livingEnemies,
  }) {
    if (livingPlayers <= 0) return RoundOutcome.defeat;
    if (livingEnemies <= 0) return RoundOutcome.waveClear;
    return RoundOutcome.ongoing;
  }

  /// One snowball.
  ///
  /// Rivals always take [hitsToKo] hits: a brief brush-off, a knockdown
  /// they get up from, then out. Allies lock up for [allyStunSeconds] on a
  /// hit that does not finish them; another hit while that stun (or the
  /// fragile flag it sets) is up knocks them out.
  static HitResolution resolveHit({
    required bool ally,
    required int hp,
    required int maxHp,
    required bool stunned,
    required bool fragile,
  }) {
    if (hp <= 0) {
      return const HitResolution(
        hp: 0,
        lockSeconds: 0,
        fragile: false,
        knockdown: false,
        knockedOut: true,
      );
    }
    if (ally && (stunned || fragile)) {
      return const HitResolution(
        hp: 0,
        lockSeconds: 0,
        fragile: false,
        knockdown: false,
        knockedOut: true,
      );
    }
    final next = hp - 1;
    if (next <= 0) {
      return const HitResolution(
        hp: 0,
        lockSeconds: 0,
        fragile: false,
        knockdown: false,
        knockedOut: true,
      );
    }
    if (ally) {
      return HitResolution(
        hp: next,
        lockSeconds: allyStunSeconds,
        fragile: true,
        knockdown: false,
        knockedOut: false,
      );
    }
    final firstHit = next >= maxHp - 1;
    if (firstHit) {
      return HitResolution(
        hp: next,
        lockSeconds: enemyBrushOffSeconds,
        fragile: false,
        knockdown: false,
        knockedOut: false,
      );
    }
    return HitResolution(
      hp: next,
      lockSeconds: enemyKnockdownSeconds,
      fragile: false,
      knockdown: true,
      knockedOut: false,
    );
  }

  /// Enemy lobs that overlap the fort are absorbed while it has HP.
  static bool fortAbsorbsShot({
    required int fortHp,
    required bool fromEnemy,
    required Rect fortRect,
    required Vector2 center,
    required double radius,
  }) {
    if (!fromEnemy || fortHp <= 0) return false;
    return ThrowPhysics.circleHitsRect(center, radius, fortRect);
  }

  /// Opaque fort art inside the 640² draft, as fractions of the sprite.
  static Rect fortHitRect({
    required int stage,
    required Vector2 anchorBottomCenter,
    required Vector2 spriteSize,
  }) {
    final (
      double left,
      double top,
      double right,
      double bottom,
    ) = switch (_clampInt(stage, 1, 3)) {
      1 => (0.10, 0.56, 0.86, 0.95),
      2 => (0.08, 0.45, 0.86, 0.95),
      _ => (0.06, 0.20, 0.88, 0.95),
    };
    final originX = anchorBottomCenter.x - spriteSize.x / 2;
    final originY = anchorBottomCenter.y - spriteSize.y;
    return Rect.fromLTRB(
      originX + spriteSize.x * left,
      originY + spriteSize.y * top,
      originX + spriteSize.x * right,
      originY + spriteSize.y * bottom,
    );
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
