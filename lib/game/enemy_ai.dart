import 'dart:math' as math;

import 'package:flame/extensions.dart';

/// Target pick, sidestep, and aim jitter for the backyard rivals.
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

  /// Horizontal sidestep in pixels, or 0 when the rival holds still.
  static double sidestep(
    math.Random rng, {
    double chance = 0.45,
    double minDistance = 36,
    double maxDistance = 90,
  }) {
    if (rng.nextDouble() > chance) return 0;
    final distance = minDistance + rng.nextDouble() * (maxDistance - minDistance);
    return rng.nextBool() ? distance : -distance;
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
