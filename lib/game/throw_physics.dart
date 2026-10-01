import 'dart:math' as math;

import 'package:flame/extensions.dart';

/// Shared throw / hit helpers (pure, unit-testable).
class ThrowPhysics {
  ThrowPhysics._();

  static const double gravity = 980;

  /// Maps charge [0..1] and aim direction into an initial velocity.
  /// Aim is expected roughly toward the enemy (positive X for player throws).
  static Vector2 launchVelocity({
    required double charge,
    required Vector2 aimDirection,
    double minSpeed = 280,
    double maxSpeed = 720,
    double speedScale = 1,
  }) {
    final clamped = charge.clamp(0.0, 1.0);
    final dir = aimDirection.clone();
    if (dir.length2 < 1e-6) {
      dir.setValues(1, -0.55);
    }
    // Prefer an upward lob: flip Y if aiming downward too hard.
    if (dir.y > -0.15) {
      dir.y = -0.45 - clamped * 0.35;
    }
    dir.normalize();
    final speed = (minSpeed + (maxSpeed - minSpeed) * clamped) * speedScale;
    return dir * speed;
  }

  /// Default aim from player toward enemy with a gentle loft.
  static Vector2 defaultAim(Vector2 from, Vector2 to) {
    final delta = to - from;
    if (delta.length2 < 1e-6) {
      return Vector2(1, -0.55);
    }
    // Bias upward so flat flicks still lob.
    delta.y = math.min(delta.y, -math.max(80.0, delta.x.abs() * 0.25));
    return delta.normalized();
  }

  static bool circlesOverlap(
    Vector2 aCenter,
    double aRadius,
    Vector2 bCenter,
    double bRadius,
  ) {
    final r = aRadius + bRadius;
    return aCenter.distanceToSquared(bCenter) <= r * r;
  }

  /// Circle vs axis-aligned rect, expanded by [radius].
  static bool circleHitsRect(Vector2 center, double radius, Rect rect) {
    final closestX = _clamp(center.x, rect.left, rect.right);
    final closestY = _clamp(center.y, rect.top, rect.bottom);
    final dx = center.x - closestX;
    final dy = center.y - closestY;
    return dx * dx + dy * dy <= radius * radius;
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
