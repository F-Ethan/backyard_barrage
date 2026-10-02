import 'dart:math' as math;

import 'package:flame/extensions.dart';

import '../meta/difficulty.dart';

/// Target pick, grid step, and aim scatter for the backyard rivals.
class EnemyAi {
  const EnemyAi._();

  static int? pickLivingIndex(List<bool> living, math.Random rng) {
    final options = <int>[];
    for (var i = 0; i < living.length; i++) {
      if (living[i]) options.add(i);
    }
    if (options.isEmpty) return null;
    return options[rng.nextInt(options.length)];
  }

  /// Prefer a living kid inside the thrower's ±1 row lane.
  static int? pickLaneTarget(
    List<bool> living,
    List<int> rows,
    int throwerRow,
    math.Random rng,
  ) {
    final inLane = <int>[];
    for (var i = 0; i < living.length; i++) {
      if (!living[i]) continue;
      final row = i < rows.length ? rows[i] : throwerRow;
      if ((row - throwerRow).abs() <= 1) inLane.add(i);
    }
    if (inLane.isNotEmpty) return inLane[rng.nextInt(inLane.length)];
    return pickLivingIndex(living, rng);
  }

  /// Seconds until the next throw, inside the difficulty's band.
  static double throwGap(math.Random rng, DifficultyTuning tuning) {
    return tuning.throwGap(rng.nextDouble());
  }

  /// One step after every [throwsPerStep] throws. The first throw does not
  /// step. [throwsCompleted] is how many lobs have already left the hand.
  static bool shouldGridStep(int throwsCompleted, int throwsPerStep) {
    if (throwsPerStep <= 1) return true;
    return throwsCompleted > 0 && throwsCompleted % throwsPerStep == 0;
  }

  /// A single orthogonal cell: one row or one column, never both, never two.
  static ({int column, int row}) gridStep(math.Random rng) {
    if (rng.nextBool()) {
      return (column: 0, row: rng.nextBool() ? 1 : -1);
    }
    return (column: rng.nextBool() ? 1 : -1, row: 0);
  }

  /// Multiplier on throw distance. Higher [radians] (early waves) miss more.
  static double rangeScatter(math.Random rng, double radians) {
    final span = radians.clamp(0.0, 0.45);
    return 1 + (rng.nextDouble() * 2 - 1) * span;
  }

  /// Unit aim vector rotated by at most [radians] in either direction.
  static Vector2 jitterAim(Vector2 aim, math.Random rng, double radians) {
    final base = aim.length2 < 1e-6 ? Vector2(-1, -0.45) : aim;
    final angle = math.atan2(base.y, base.x);
    final delta = (rng.nextDouble() * 2 - 1) * radians;
    final next = angle + delta;
    return Vector2(math.cos(next), math.sin(next));
  }
}
