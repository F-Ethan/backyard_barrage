import 'dart:math' as math;

import 'package:flame/extensions.dart';

/// Shared throw / hit helpers (pure, unit-testable).
class ThrowPhysics {
  ThrowPhysics._();

  static const double gravity = 980;

  /// A tap still lobs, but it dies in the neutral band.
  static const double minSpeed = 560;

  /// Full power from the back line reaches the far enemy row.
  static const double maxSpeed = 1180;

  static const double _minLoft = 16 * math.pi / 180;
  static const double _maxLoft = 32 * math.pi / 180;

  static double speedForCharge(double charge, {double speedScale = 1}) {
    final clamped = charge.clamp(0.0, 1.0);
    return (minSpeed + (maxSpeed - minSpeed) * clamped) * speedScale;
  }

  /// Charge in `[0, 1]` after holding for [held] seconds.
  ///
  /// The fill rate falls as the bar gets fuller: half the hold time is already
  /// past the halfway mark on the bar.
  static double chargeForHold(double held, double duration) {
    if (duration <= 0) return 1;
    final u = (held / duration).clamp(0.0, 1.0);
    return 1 - (1 - u) * (1 - u);
  }

  /// Maps charge `[0..1]` and aim direction into an initial velocity.
  ///
  /// Steep flicks are flattened into a low lob so max power carries across
  /// the yard instead of climbing off the top of the screen.
  static Vector2 launchVelocity({
    required double charge,
    required Vector2 aimDirection,
    double minSpeed = minSpeed,
    double maxSpeed = maxSpeed,
    double speedScale = 1,
  }) {
    final clamped = charge.clamp(0.0, 1.0);
    final dir = aimDirection.clone();
    if (dir.length2 < 1e-6) {
      dir.setValues(1, -0.4);
    }
    final facing = dir.x < 0 ? -1.0 : 1.0;
    var loft = math.atan2(-dir.y, dir.x.abs());
    if (loft < _minLoft) loft = _minLoft;
    if (loft > _maxLoft) loft = _maxLoft;
    final flattened = loft * (1 - 0.12 * clamped);
    final angle = flattened < _minLoft ? _minLoft : flattened;
    final speed = (minSpeed + (maxSpeed - minSpeed) * clamped) * speedScale;
    return Vector2(facing * speed * math.cos(angle), -speed * math.sin(angle));
  }

  /// Flatter ballistic that hits [to] at [speed], or null when [speed] is
  /// too low to get there.
  static Vector2? launchToward({
    required Vector2 from,
    required Vector2 to,
    required double speed,
  }) {
    final dx = to.x - from.x;
    final dyUp = from.y - to.y;
    if (dx.abs() < 8 || speed < 1) return null;
    final v2 = speed * speed;
    final disc = v2 * v2 - gravity * (gravity * dx * dx + 2 * dyUp * v2);
    if (disc < 0) return null;
    final root = math.sqrt(disc);
    final theta = math.atan((v2 - root) / (gravity * dx));
    return Vector2(speed * math.cos(theta), -speed * math.sin(theta));
  }

  /// Horizontal pace of a full-power lob. Kids are capped at this, which is
  /// below the launch speed, so they cannot outrun a snowball.
  static double kidMoveSpeed({double speedScale = 1}) {
    final shot = launchVelocity(
      charge: 1,
      aimDirection: Vector2(1, -0.45),
      speedScale: speedScale,
    );
    final pace = shot.x.abs();
    if (pace > shot.length) return shot.length;
    return pace;
  }

  static double apexRise(Vector2 velocity) {
    if (velocity.y >= 0) return 0;
    return (velocity.y * velocity.y) / (2 * gravity);
  }

  /// Default aim from a thrower toward a target with a gentle loft.
  static Vector2 defaultAim(Vector2 from, Vector2 to) {
    final delta = to - from;
    if (delta.length2 < 1e-6) {
      return Vector2(1, -0.4);
    }
    if (delta.y > -40) {
      delta.y = -math.max(40.0, delta.x.abs() * 0.18);
    }
    return delta;
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
