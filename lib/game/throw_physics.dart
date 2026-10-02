import 'dart:math' as math;

import 'package:flame/extensions.dart';

import 'arena_grid.dart';

/// What a fort does to a snowball or water balloon that meets it.
enum FortShotResult { none, blocked, damaged }

/// A gravity lob whose peak and landing stay inside the thrower's row lane.
class RowLob {
  const RowLob({
    required this.velocity,
    required this.throwerRow,
    required this.throwerColumn,
    required this.peakRow,
    required this.landingRow,
    required this.apexRise,
    required this.landingDrop,
    required this.range,
  });

  final Vector2 velocity;
  final int throwerRow;
  final int throwerColumn;
  final int peakRow;
  final int landingRow;

  /// Pixels the arc climbs above the throw origin.
  final double apexRise;

  /// Pixels the landing sits below the throw origin. Negative lands higher.
  final double landingDrop;
  final double range;
}

/// Shared throw / hit helpers (pure, unit-testable).
class ThrowPhysics {
  ThrowPhysics._();

  static const double gravity = 980;

  /// A tap still lobs, but it dies in the neutral band.
  static const double minSpeed = 560;

  /// Full power from the back line reaches the far enemy row.
  static const double maxSpeed = 1180;

  /// Quick taps throw at this fraction of a full lob. Never near zero.
  static const double minThrowCharge = 1 / 3;

  /// Rows a lob may rise above or drop below the thrower's row.
  static const int laneRows = 1;

  /// Half-range of a tap and a full hold, before throw-rank speed.
  static const double tapRange = 230;
  static const double fullRange = 960;

  /// `z` in `erf(z * u) / erf(z)`. Chosen so one third of the hold (1s of a
  /// 3s charge) lands on half power.
  static const double chargeBellZ = 1.33323;

  static const double _minLoft = 16 * math.pi / 180;
  static const double _maxLoft = 32 * math.pi / 180;

  static double speedForCharge(double charge, {double speedScale = 1}) {
    final clamped = charge.clamp(0.0, 1.0);
    return (minSpeed + (maxSpeed - minSpeed) * clamped) * speedScale;
  }

  /// Charge in `[minThrowCharge, 1]` after holding for [held] seconds.
  ///
  /// The shape is the rising half of a Gaussian CDF (`erf`), from the mean
  /// out into the tail. Fill rate is the right half of a bell: fastest at
  /// the start of the climb, then progressively slower.
  ///
  /// Anchors when [duration] is 3 seconds (throw rank 0):
  /// a tap stays at about 1/3, ~1 second is half power, ~3 seconds is full.
  /// The top half of the bar (1/2 → 1) takes the remaining two seconds.
  static double chargeForHold(double held, double duration) {
    if (duration <= 0 || held >= duration) return 1;
    if (held <= 0) return minThrowCharge;
    final u = (held / duration).clamp(0.0, 1.0);
    final bell = _erf(chargeBellZ * u) / _erf(chargeBellZ);
    if (bell < minThrowCharge) return minThrowCharge;
    if (bell > 1) return 1;
    return bell;
  }

  static double rangeForCharge(double charge, {double speedScale = 1}) {
    final c = charge.clamp(minThrowCharge, 1.0);
    final t = (c - minThrowCharge) / (1 - minThrowCharge);
    return (tapRange + (fullRange - tapRange) * t) * speedScale;
  }

  static bool inThrowLane(int throwerRow, int targetRow) {
    return (targetRow - throwerRow).abs() <= laneRows;
  }

  /// Peak and landing rows for a player lob. Full power peaks one row up
  /// (it can sail over a same-row target) and lands on the aimed row.
  /// A tap lands up to one row below and does not climb a row.
  static ({int peak, int landing}) rowsForCharge({
    required int throwerRow,
    required int aimRow,
    required double charge,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    final c = charge.clamp(0.0, 1.0);
    final power = ((c - minThrowCharge) / (1 - minThrowCharge)).clamp(0.0, 1.0);
    var peak = row;
    if (power >= 0.82 && row > 0) peak = row - 1;
    final aimDelta = (aimRow - row).clamp(-laneRows, laneRows);
    var landDelta = aimDelta;
    if (power < 0.4) {
      landDelta = (aimDelta + 1).clamp(-laneRows, laneRows);
    }
    var landing = row + landDelta;
    if (landing < 0) landing = 0;
    if (landing >= ArenaGrid.rows) landing = ArenaGrid.rows - 1;
    if (landing < row - laneRows) landing = row - laneRows;
    if (landing > row + laneRows) landing = row + laneRows;
    if (peak < row - laneRows) peak = row - laneRows;
    if (peak > row) peak = row;
    return (peak: peak, landing: landing);
  }

  static RowLob planPlayerLob({
    required int throwerRow,
    required int throwerColumn,
    required int aimRow,
    required double charge,
    required bool facingRight,
    double speedScale = 1,
    required double originY,
  }) {
    final rows = rowsForCharge(
      throwerRow: throwerRow,
      aimRow: aimRow,
      charge: charge,
    );
    return _buildLob(
      throwerRow: throwerRow,
      throwerColumn: throwerColumn,
      peakRow: rows.peak,
      landingRow: rows.landing,
      range: rangeForCharge(charge, speedScale: speedScale),
      facingRight: facingRight,
      originY: originY,
    );
  }

  /// Enemy lobs land on the target's row when it is in the lane, with a
  /// one-row arc so a nearer kid in the same row can be sailed over.
  static RowLob planEnemyLob({
    required int throwerRow,
    required int throwerColumn,
    required int targetRow,
    required double distance,
    required double rangeScale,
    required bool facingRight,
    required double originY,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    var landing = targetRow;
    if (landing < row - laneRows) landing = row - laneRows;
    if (landing > row + laneRows) landing = row + laneRows;
    if (landing < 0) landing = 0;
    if (landing >= ArenaGrid.rows) landing = ArenaGrid.rows - 1;
    final peak = row > 0 ? row - 1 : row;
    final scale = rangeScale.clamp(0.55, 1.45);
    final range = distance.abs().clamp(180.0, 1100.0) * scale;
    return _buildLob(
      throwerRow: row,
      throwerColumn: throwerColumn,
      peakRow: peak,
      landingRow: landing,
      range: range,
      facingRight: facingRight,
      originY: originY,
    );
  }

  static RowLob _buildLob({
    required int throwerRow,
    required int throwerColumn,
    required int peakRow,
    required int landingRow,
    required double range,
    required bool facingRight,
    required double originY,
  }) {
    var rise = peakRow < throwerRow
        ? originY - ArenaGrid.laneY(peakRow)
        : math.min(ArenaGrid.rowStep * 0.22, 10.0);
    if (rise < 8) rise = 8.0;
    final drop = ArenaGrid.laneY(landingRow) - originY;
    if (drop < 0 && rise < -drop + 4) {
      rise = -drop + 4;
    }
    final velocity = _arcVelocity(
      rise: rise,
      drop: drop,
      range: range,
      facingRight: facingRight,
    );
    return RowLob(
      velocity: velocity,
      throwerRow: throwerRow,
      throwerColumn: throwerColumn,
      peakRow: peakRow,
      landingRow: landingRow,
      apexRise: rise,
      landingDrop: drop,
      range: range,
    );
  }

  static Vector2 _arcVelocity({
    required double rise,
    required double drop,
    required double range,
    required bool facingRight,
  }) {
    final h = rise < 8 ? 8.0 : rise;
    final vy = -math.sqrt(2 * gravity * h);
    final disc = vy * vy + 2 * gravity * drop;
    final t = disc <= 0
        ? (-vy / gravity) * 2
        : (-vy + math.sqrt(disc)) / gravity;
    final safeT = t < 0.05 ? 0.05 : t;
    final vx = range / safeT;
    return Vector2(facingRight ? vx : -vx, vy);
  }

  /// Logical row along a [RowLob]. Stays inside the thrower's ±1 band.
  /// The arc sits on the peak row through the middle, so a full-power throw
  /// sails over a same-row target and comes down on the landing row.
  static int lobRow({
    required int throwerRow,
    required int peakRow,
    required int landingRow,
    required double originY,
    required double apexRise,
    required double landingDrop,
    required double y,
    required double vy,
  }) {
    int clampLane(int row) {
      var next = row;
      final low = throwerRow - laneRows;
      final high = throwerRow + laneRows;
      if (next < low) next = low;
      if (next > high) next = high;
      if (next < 0) return 0;
      if (next >= ArenaGrid.rows) return ArenaGrid.rows - 1;
      return next;
    }

    if (apexRise <= 1) {
      return clampLane(vy > 40 ? landingRow : throwerRow);
    }
    final apexY = originY - apexRise;
    if (vy <= 0) {
      final climbed = (originY - y).clamp(0.0, apexRise);
      final t = climbed / apexRise;
      return clampLane(t < 0.72 ? throwerRow : peakRow);
    }
    final landY = originY + landingDrop;
    final fallSpan = landY - apexY;
    if (fallSpan <= 1) return clampLane(landingRow);
    final fallen = (y - apexY).clamp(0.0, fallSpan);
    final t = fallen / fallSpan;
    return clampLane(t < 0.72 ? peakRow : landingRow);
  }

  /// True in the short window around the top of the arc.
  static bool nearArcPeak({
    required double velocityY,
    required double launchVy,
  }) {
    if (launchVy >= -40) return false;
    return velocityY.abs() <= launchVy.abs() * 0.22;
  }

  /// X of the apex for a shot that started at [originX] with [velocity].
  static double apexX({
    required double originX,
    required Vector2 velocity,
    required double launchVy,
  }) {
    if (launchVy >= 0) return originX;
    final tApex = -launchVy / gravity;
    return originX + velocity.x * tApex;
  }

  /// Fort vs snowball. Peak shots clear. Shots from behind your own fort
  /// are blocked without damage unless [friendlyDamage] is on. Opponent
  /// shots that are not at the peak damage the fort.
  static FortShotResult resolveFortShot({
    required bool overlaps,
    required bool atPeak,
    required bool sameSide,
    required bool throwerBehind,
    required bool friendlyDamage,
  }) {
    if (!overlaps || atPeak) return FortShotResult.none;
    if (sameSide && !throwerBehind) return FortShotResult.none;
    if (sameSide) {
      return friendlyDamage ? FortShotResult.damaged : FortShotResult.blocked;
    }
    return FortShotResult.damaged;
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

  /// Horizontal pace of a full-power lane lob. Kids are capped at this so
  /// they cannot outrun a snowball. [speedScale] is the throw-rank multiplier.
  static double kidMoveSpeed({double speedScale = 1}) {
    final originY = ArenaGrid.laneY(4) - ArenaGrid.kidSize * 0.1;
    final shot = planPlayerLob(
      throwerRow: 4,
      throwerColumn: 0,
      aimRow: 4,
      charge: 1,
      facingRight: true,
      speedScale: speedScale,
      originY: originY,
    );
    return shot.velocity.x.abs();
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

  /// Abramowitz and Stegun 7.1.26. Max error about 1.5e-7.
  static double _erf(double x) {
    final sign = x < 0 ? -1.0 : 1.0;
    final a = x.abs();
    const p = 0.3275911;
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    final t = 1.0 / (1.0 + p * a);
    final y =
        1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-a * a);
    return sign * y;
  }
}
