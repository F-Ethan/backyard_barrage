import 'package:flame/extensions.dart';

import 'throw_physics.dart';

enum RoundOutcome { ongoing, waveClear, defeat }

/// Wave size, fort cover, and upgrade scaling. Pure so tests can lock it.
class CombatRules {
  const CombatRules._();

  static const int hitsToKo = 2;

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

  /// Seconds to reach a full player charge. Throw-speed ranks shorten it.
  static double playerChargeSeconds(int throwRank) {
    final rank = _clampInt(throwRank, 0, 5);
    final seconds = 0.85 - rank * 0.07;
    if (seconds < 0.45) return 0.45;
    if (seconds > 0.85) return 0.85;
    return seconds;
  }

  static double projectileSpeedScale(int throwRank) {
    final rank = _clampInt(throwRank, 0, 5);
    return 1 + rank * 0.07;
  }

  static double enemyChargeSeconds(int wave) {
    final steps = wave < 1 ? 0 : wave - 1;
    final seconds = 1.2 - steps * 0.07;
    if (seconds < 0.55) return 0.55;
    return seconds.toDouble();
  }

  /// Aim error in radians. Higher waves tighten it.
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
