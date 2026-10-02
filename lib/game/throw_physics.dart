import 'dart:math' as math;

import 'package:flame/extensions.dart';

import 'arena_grid.dart';

/// What a fort does to a snowball or water balloon that meets it.
enum FortShotResult { none, blocked, damaged }

/// A lob. Enemy shots are ballistic. Player shots are [scripted]: constant
/// pace, with aim choosing the row instead of a realistic arc.
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
    this.scripted = false,
    this.travelSpeed = 0,
    this.originY = 0,
    this.landingY = 0,
    this.apexY = 0,
    this.apexFraction = 0.5,
    this.settleFraction = 0.72,
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

  /// Player lobs follow [ThrowPhysics.playerArcY] instead of gravity.
  final bool scripted;
  final double travelSpeed;
  final double originY;
  final double landingY;
  final double apexY;

  /// Fraction of [range] where the loft peaks, and where the ball locks
  /// onto the committed lane.
  final double apexFraction;
  final double settleFraction;

  double yAt(double u) {
    if (!scripted) return originY;
    return ThrowPhysics.playerArcY(
      originY: originY,
      apexY: apexY,
      landingY: landingY,
      u: u,
      apexFraction: apexFraction,
      settleFraction: settleFraction,
    );
  }

  int rowAt(double u) {
    if (!scripted) return landingRow;
    return ThrowPhysics.playerArcRow(
      throwerRow: throwerRow,
      landingRow: landingRow,
      u: u,
      settleFraction: settleFraction,
    );
  }

  /// World X of the loft peak. Player shots place it on the scripted path.
  double apexWorldX(double originX) {
    final facing = velocity.x < 0 ? -1.0 : 1.0;
    if (!scripted) {
      return ThrowPhysics.apexX(
        originX: originX,
        velocity: velocity,
        launchVy: velocity.y,
      );
    }
    return originX + facing * range * apexFraction;
  }
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

  /// Width of the hit band around the row a shot has committed to.
  static const int laneRows = 1;

  /// Far edge of the letterboxed yard. Full power from the back line
  /// reaches this, plus a small margin so the ball center clears it.
  static const double yardFarEdge = 1280;

  /// A tap dies in the neutral band. Full power is computed so a back-line
  /// throw reaches [yardFarEdge].
  static const double tapRange = 250;

  /// Horizontal pace of every player lob. Throw rank may scale it.
  ///
  /// This is the pre-lane launch pace (about 900 px/s), not the lane arc
  /// that crossed the yard near 2000 px/s. More charge adds range, and
  /// the flight simply lasts longer.
  static const double playerTravelSpeed = 920;

  /// Loft above the higher of the throw point and the landing lane.
  /// Kept short so a flat lob can still peak inside the fort footprint.
  static const double playerLoft = 12;

  /// Where along the range the loft peaks, and where the ball locks onto
  /// the aimed row. The lock happens in the neutral band on a full throw.
  static const double playerApexFraction = 0.22;
  static const double playerSettleFraction = 0.42;

  /// Field of throw measured from horizontal. Straight up becomes 45°.
  static const double maxAimRadians = math.pi / 4;

  /// Rows a ±45° aim commits, at a tap and at full power.
  /// A steep tap climbs about one row; a steep full throw climbs several.
  static const double aimRowsAtTap = 1.2;
  static const double aimRowsAtFull = 3.5;

  /// One grid step takes this long at the hard walk cap. Ten times the old
  /// 120ms cadence, so a column is about 1.2 seconds. A row is a shorter
  /// distance at the same speed, so it finishes a little sooner.
  static const double stepSeconds = 1.2;

  static double get backLineThrowX =>
      ArenaGrid.playerLeft + ArenaGrid.kidSize * 0.22;

  static double get fullRange {
    final reach = yardFarEdge - backLineThrowX + 40;
    if (reach < 980) return 980;
    return reach;
  }

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

  /// Distance a player lob travels. Charge changes this, not the pace.
  /// Throw-rank speed is applied separately in [planPlayerLob].
  static double rangeForCharge(double charge) {
    final c = charge.clamp(minThrowCharge, 1.0);
    final t = (c - minThrowCharge) / (1 - minThrowCharge);
    return tapRange + (fullRange - tapRange) * t;
  }

  static double _chargePower(double charge) {
    final c = charge.clamp(minThrowCharge, 1.0);
    return ((c - minThrowCharge) / (1 - minThrowCharge)).clamp(0.0, 1.0);
  }

  static bool inThrowLane(int throwerRow, int targetRow) {
    return (targetRow - throwerRow).abs() <= laneRows;
  }

  /// Player hit check. The throw still commits to a lane, but the kid has
  /// to be standing on the ball's current row. One step off that path misses.
  static bool playerCanHit({
    required int landingRow,
    required int shotRow,
    required int targetRow,
  }) {
    if ((targetRow - landingRow).abs() > laneRows) return false;
    return targetRow == shotRow;
  }

  /// Folds [aimDirection] into a forward cone of ±[maxAimRadians].
  /// Straight up and straight down become the cone edges, still with a
  /// forward component, so a lob cannot be thrown vertically.
  static Vector2 clampAimDirection(
    Vector2 aimDirection, {
    required bool facingRight,
  }) {
    final forward = facingRight ? 1.0 : -1.0;
    var x = aimDirection.x;
    var y = aimDirection.y;
    if (x.abs() < 1e-8 && y.abs() < 1e-8) {
      return Vector2(forward, 0);
    }
    if (x * forward <= 0) {
      x = forward * (y.abs() < 1e-8 ? 1.0 : y.abs());
    }
    var elevation = math.atan2(-y, x.abs());
    if (elevation > maxAimRadians) elevation = maxAimRadians;
    if (elevation < -maxAimRadians) elevation = -maxAimRadians;
    return Vector2(forward * math.cos(elevation), -math.sin(elevation));
  }

  /// Radians above horizontal after [clampAimDirection]. Positive is up.
  static double aimElevation(
    Vector2 aimDirection, {
    required bool facingRight,
  }) {
    final aim = clampAimDirection(aimDirection, facingRight: facingRight);
    return math.atan2(-aim.y, aim.x.abs());
  }

  /// Row the player commits to. Steeper aim climbs more rows than a flat
  /// throw at the same charge. More charge reaches more rows at the same angle.
  static int committedRow({
    required int throwerRow,
    required double elevation,
    required double charge,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    final power = _chargePower(charge);
    final reach = aimRowsAtTap + (aimRowsAtFull - aimRowsAtTap) * power;
    final aim01 = (elevation / maxAimRadians).clamp(-1.0, 1.0);
    final delta = -aim01 * reach;
    var landing = (row + delta).round();
    if (landing < 0) landing = 0;
    if (landing >= ArenaGrid.rows) landing = ArenaGrid.rows - 1;
    return landing;
  }

  static RowLob planPlayerLob({
    required int throwerRow,
    required int throwerColumn,
    required Vector2 aimDirection,
    required double charge,
    required bool facingRight,
    double speedScale = 1,
    required double originY,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    final elevation = aimElevation(aimDirection, facingRight: facingRight);
    final landing = committedRow(
      throwerRow: row,
      elevation: elevation,
      charge: charge,
    );
    final landingY = ArenaGrid.laneY(landing);
    final chordHigh = math.min(originY, landingY);
    final apexY = chordHigh - playerLoft;
    final rise = originY - apexY;
    final range = rangeForCharge(charge);
    final scale = speedScale.clamp(0.2, 3.0);
    final speed = playerTravelSpeed * scale;
    final facing = facingRight ? 1.0 : -1.0;
    final initialVy = playerArcVelocity(
      facing: facing,
      speed: speed,
      originY: originY,
      apexY: apexY,
      landingY: landingY,
      u: 0,
      apexFraction: playerApexFraction,
      settleFraction: playerSettleFraction,
      range: range,
    ).y;
    var peak = math.min(row, landing);
    if (_chargePower(charge) >= 0.82 && peak > 0) peak -= 1;
    return RowLob(
      velocity: Vector2(facing * speed, initialVy),
      throwerRow: row,
      throwerColumn: throwerColumn.clamp(0, ArenaGrid.columnsPerSide - 1),
      peakRow: peak,
      landingRow: landing,
      apexRise: rise < 1 ? 1 : rise,
      landingDrop: landingY - originY,
      range: range,
      scripted: true,
      travelSpeed: speed,
      originY: originY,
      landingY: landingY,
      apexY: apexY,
      apexFraction: playerApexFraction,
      settleFraction: playerSettleFraction,
    );
  }

  /// Height of a scripted player lob. [u] is distance traveled / range.
  static double playerArcY({
    required double originY,
    required double apexY,
    required double landingY,
    required double u,
    required double apexFraction,
    required double settleFraction,
  }) {
    final uu = u.clamp(0.0, 1.0);
    if (uu <= apexFraction) {
      final af = apexFraction <= 1e-6 ? 1.0 : apexFraction;
      final t = uu / af;
      final s = 1 - (1 - t) * (1 - t);
      return originY + (apexY - originY) * s;
    }
    if (uu >= settleFraction) return landingY;
    final span = settleFraction - apexFraction;
    final t = span <= 1e-6 ? 1.0 : (uu - apexFraction) / span;
    final s = t * t;
    return apexY + (landingY - apexY) * s;
  }

  /// Logical row along a scripted lob. Locked to the landing row once the
  /// ball has settled, which is before it reaches the enemy half.
  static int playerArcRow({
    required int throwerRow,
    required int landingRow,
    required double u,
    required double settleFraction,
  }) {
    final uu = u.clamp(0.0, 1.0);
    if (uu >= settleFraction) return landingRow;
    final span = settleFraction <= 1e-6 ? 1.0 : settleFraction;
    final t = uu / span;
    var row = (throwerRow + (landingRow - throwerRow) * t).round();
    if (row < 0) return 0;
    if (row >= ArenaGrid.rows) return ArenaGrid.rows - 1;
    return row;
  }

  static Vector2 playerArcVelocity({
    required double facing,
    required double speed,
    required double originY,
    required double apexY,
    required double landingY,
    required double u,
    required double apexFraction,
    required double settleFraction,
    required double range,
  }) {
    final duDt = range <= 1 ? 0.0 : speed / range;
    final uu = u.clamp(0.0, 1.0);
    double dyDu;
    if (uu <= apexFraction) {
      final af = apexFraction <= 1e-6 ? 1.0 : apexFraction;
      final t = uu / af;
      dyDu = (apexY - originY) * (2 - 2 * t) / af;
    } else if (uu >= settleFraction) {
      dyDu = 0;
    } else {
      final span = settleFraction - apexFraction;
      final safe = span <= 1e-6 ? 1.0 : span;
      final t = (uu - apexFraction) / safe;
      dyDu = (landingY - apexY) * (2 * t) / safe;
    }
    return Vector2(facing * speed, dyDu * duDt);
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

  /// Fort vs snowball. Peak shots clear. A collapsed fort does not block
  /// either direction. Shots from behind your own standing fort are blocked
  /// without damage unless [friendlyDamage] is on. Opponent shots that are
  /// not at the peak damage a standing fort.
  static FortShotResult resolveFortShot({
    required bool overlaps,
    required bool atPeak,
    required bool sameSide,
    required bool throwerBehind,
    required bool friendlyDamage,
    bool collapsed = false,
  }) {
    if (!overlaps || atPeak || collapsed) return FortShotResult.none;
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

  /// Hard cap on kid walking, in pixels per second.
  ///
  /// One column takes [stepSeconds]. Throw rank does not speed this up;
  /// difficulty applies its own scale on top in the match.
  static double kidMoveSpeed() {
    return ArenaGrid.columnStep / stepSeconds;
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
