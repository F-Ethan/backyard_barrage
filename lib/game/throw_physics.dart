import 'dart:math' as math;

import 'package:flame/extensions.dart';

import 'arena_grid.dart';

/// What a fort does to a snowball or water balloon that meets it.
enum FortShotResult { none, blocked, damaged }

/// A lob. Live shots use a [groundTrack]: constant pace, depth set by aim,
/// and a drawn loft that meets that track at the hand and at the landing.
/// [scripted] remains for the older lane path.
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
    this.groundTrack = false,
    this.travelSpeed = 0,
    this.originY = 0,
    double? trackY,
    this.landingY = 0,
    this.apexY = 0,
    this.apexFraction = 0.5,
    this.settleFraction = 0.72,
  }) : _trackY = trackY;

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

  /// Hit path is a straight depth line. The sprite lofts above it.
  final bool groundTrack;
  final double travelSpeed;
  final double originY;

  /// Body height where the ground track starts. The hand ([originY]) sits
  /// a little above it; the drawn ball eases from the hand onto the track.
  double get trackY => _trackY ?? originY;
  final double? _trackY;
  final double landingY;
  final double apexY;

  /// Fraction of [range] where the loft peaks, and where the ball locks
  /// onto the committed lane.
  final double apexFraction;
  final double settleFraction;

  double yAt(double u) {
    if (groundTrack) {
      final uu = u.clamp(0.0, 1.0);
      return trackY + (landingY - trackY) * uu;
    }
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
    if (groundTrack) return ArenaGrid.rowForLaneY(yAt(u));
    if (!scripted) return landingRow;
    return ThrowPhysics.playerArcRow(
      throwerRow: throwerRow,
      landingRow: landingRow,
      u: u,
      settleFraction: settleFraction,
    );
  }

  /// World X of the loft peak.
  double apexWorldX(double originX) {
    final facing = velocity.x < 0 ? -1.0 : 1.0;
    if (scripted || groundTrack) {
      return originX + facing * range * apexFraction;
    }
    return ThrowPhysics.apexX(
      originX: originX,
      velocity: velocity,
      launchVy: velocity.y,
    );
  }
}

/// Upright yaw while a charge sweeps along a row.
///
/// Order from the up-screen end of the row to the down-screen end:
/// [yaw30l], [yaw15l], [across], [yaw15r], [yaw30r].
/// [across] is the existing side-profile charge pose. The other four are
/// mild screen-left / screen-right yaws. None of these poses face the
/// camera or show the back of the coat. Player winter draws the 3D frames
/// that point screen-left (`30l`, `15l`, and the sheet charge) mirrored so
/// the kid still faces +x toward the rivals. Enemy sprites are never
/// mirrored from player art.
enum ChargeYaw { yaw30l, yaw15l, across, yaw15r, yaw30r }

/// Shared throw / hit helpers (pure, unit-testable).
class ThrowPhysics {
  ThrowPhysics._();

  /// True when the loft peak is already past [footprint] in the throw
  /// direction, so the ball has cleared that fort.
  static bool peaksPastFort({
    required double apexX,
    required Rect footprint,
    required bool facingRight,
  }) {
    if (facingRight) return apexX > footprint.right;
    return apexX < footprint.left;
  }

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

  /// How long one up-and-down aim sweep takes while a charge is held.
  /// One third of the old 1.2s rate, so the release window is wider.
  static const double swivelPeriod = 3.6;

  /// Where along a ground-track lob the drawn loft peaks.
  static const double groundApexFraction = 0.5;

  /// A kid's hit circle, as a fraction of sprite width. Small enough that a
  /// ball can pass the sprite without a touch.
  static const double kidHitScale = 0.16;

  /// Depth slop, as a fraction of one row, on each side of the kid. Half a
  /// row each way covers the whole yard with no dead band between rows, and
  /// a kid one full row off the track still sees it pass in front or behind.
  static const double depthWindowFraction = 0.5;

  /// Rival ground-track pace. Faster than the player's lob.
  static const double enemyTravelSpeed = 1400;

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

  /// Depth the ball drifts per pixel forward at the end of the sweep.
  ///
  /// The swept angle is the ground track itself: the aim arrow, the dotted
  /// preview, and the hit path are one line. From mid-yard, a full sweep at
  /// the rivals' distance (about 700px) covers ±140px, the whole enemy half.
  static const double maxAimSlope = 0.2;

  /// Sweep cone, measured from horizontal (about ±11.3°). Matches
  /// [maxAimSlope] so the drawn arrow and the track never disagree.
  ///
  /// Rival shots do not use this cone. Their scatter stays on the
  /// difficulty profile (`CombatRules.enemyAimJitterRadians`).
  static final double maxAimRadians = math.atan(maxAimSlope);

  /// Sweep speed while the aim line is on a rival. The sweep lingers there
  /// so a release on target is a fair timing window, not a frame.
  static const double aimFriction = 0.35;

  /// A release that misses a rival by no more than this many pixels of
  /// depth (beyond the contact window) is nudged onto them.
  static const double aimAssistPx = 14;

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

  /// Charge in `[minThrowCharge, 1]` after holding for [held] seconds.
  ///
  /// Starts at the tap minimum and climbs at a steady rate from the first
  /// frame, so the bar never sits still. Anchors when [duration] is 3 seconds
  /// (throw rank 0): a tap is 1/3, ~1 second is a little over half, and
  /// ~3 seconds is full.
  static double chargeForHold(double held, double duration) {
    if (duration <= 0 || held >= duration) return 1;
    if (held <= 0) return minThrowCharge;
    final u = (held / duration).clamp(0.0, 1.0);
    return minThrowCharge + (1 - minThrowCharge) * u;
  }

  /// Charge at which the pan starts: just before power tops out, so the
  /// start is gentle but the aim is live by the time the bar is full.
  static const double sweepStartCharge = 0.85;

  /// Pan speed in radians per second: the same average as one
  /// [swivelPeriod] back-and-forth across ±[maxAimRadians].
  static double get sweepSpeed => 4 * maxAimRadians / swivelPeriod;

  /// X of the middle of the rival half, where the pan limits are measured.
  static double get rivalDepthX =>
      (ArenaGrid.enemyLeft + ArenaGrid.enemyRight) / 2;

  /// Lowest and highest pan angle for a track starting at [start]: the
  /// angles that reach the front and back lanes at the rivals' distance,
  /// inside ±[maxAimRadians]. The pan turns around there, so it never
  /// presses against the yard edge and appears to stall.
  static (double, double) sweepLimits(Vector2 start) {
    final d = math.max(200.0, rivalDepthX - start.x);
    final up = math
        .atan((start.y - ArenaGrid.laneY(0)) / d)
        .clamp(0.0, maxAimRadians);
    final down = math
        .atan((ArenaGrid.laneY(ArenaGrid.rows - 1) - start.y) / d)
        .clamp(0.0, maxAimRadians);
    return (-down, up);
  }

  /// How quickly the sweep speed blends into and out of [aimFriction], per
  /// second. The pan slows smoothly on a rival instead of snapping.
  static const double aimFrictionBlend = 10;

  /// Distance a player lob travels. Charge changes this, not the pace.
  /// Throw-rank speed is applied separately in [planPlayerLob].
  static double rangeForCharge(double charge) {
    final c = charge.clamp(minThrowCharge, 1.0);
    final t = (c - minThrowCharge) / (1 - minThrowCharge);
    return tapRange + (fullRange - tapRange) * t;
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

  /// Which upright sprite the charge sweep should show.
  ///
  /// [elevation] is screen-up radians from the charge sweep. The up-screen
  /// end of the row is +[maxAimRadians] (`30l`). Straight across the yard is
  /// 0 (the existing charge pose). The down-screen end is -[maxAimRadians]
  /// (`30r`). Five equal bands, same on both sides:
  /// `30l → 15l → charge → 15r → 30r`. Player winter mirrors the
  /// screen-left frames so the kid faces +x. Enemy art is not mirrored.
  static ChargeYaw chargeYaw(double elevation) {
    if (maxAimRadians <= 0) return ChargeYaw.across;
    final u = (elevation / maxAimRadians).clamp(-1.0, 1.0);
    if (u >= 0.6) return ChargeYaw.yaw30l;
    if (u >= 0.2) return ChargeYaw.yaw15l;
    if (u >= -0.2) return ChargeYaw.across;
    if (u >= -0.6) return ChargeYaw.yaw15r;
    return ChargeYaw.yaw30r;
  }

  /// Forward aim at [elevation] radians. Positive elevation aims up the screen.
  static Vector2 aimForElevation(
    double elevation, {
    required bool facingRight,
  }) {
    final clamped = elevation.clamp(-maxAimRadians, maxAimRadians);
    final forward = facingRight ? 1.0 : -1.0;
    return Vector2(forward * math.cos(clamped), -math.sin(clamped));
  }

  /// Peak of the drawn snowball hump, in pixels, for every aim and range.
  ///
  /// Tall enough that the sprite climbs off the hand and drops onto the
  /// landing. It does not grow with range. The old hump did (`range * 0.18`,
  /// clamped to 48–120), so a full down-aim still hung in the far lanes and
  /// up-aims were the ones that looked like they connected. Hits stay on the
  /// ground track, and this lift is the same for an up-aim and a down-aim,
  /// so the picture keeps the depth the track already chose.
  static const double visualLoftPeak = 64;

  /// Drawn loft above the ground track. Zero at the hand and at the landing.
  ///
  /// [range] does not change the height. A long throw and a short throw
  /// share [visualLoftPeak]. The shape is `4 u (1-u)`, so the ball leaves
  /// the hand climbing and is back on the track at the landing.
  static double loftAt(double u, double range) {
    final uu = u.clamp(0.0, 1.0);
    if (range.isNaN || range.abs() < 1) return 0;
    return visualLoftPeak * 4 * uu * (1 - uu);
  }

  /// Sprite Y for a ground-track lob. [u] is distance traveled / range.
  ///
  /// The chord from [originY] to [landingY] is the hit path. The loft sits
  /// on that chord, so aiming up draws higher on the screen than aiming
  /// down by the same gap the hit path uses.
  static double drawnLobY({
    required double originY,
    required double landingY,
    required double u,
    required double range,
  }) {
    final uu = u.clamp(0.0, 1.0);
    final chord = originY + (landingY - originY) * uu;
    return chord - loftAt(uu, range);
  }

  /// Contact in ground-track space. The depth window is tighter than the
  /// circle, so a ball whose track is in front of or behind the kid misses
  /// even when the drawn sprite crosses the body.
  static bool snowballContacts({
    required Vector2 ground,
    required double shotRadius,
    required Vector2 kidCenter,
    required double kidRadius,
  }) {
    final window = ArenaGrid.rowStep * depthWindowFraction;
    if ((ground.y - kidCenter.y).abs() > window) return false;
    return circlesOverlap(ground, shotRadius, kidCenter, kidRadius);
  }

  /// [snowballContacts] anywhere on the ground segment [from]→[to] the ball
  /// covered this frame. A fast shot or a long frame cannot step over a kid.
  static bool snowballSweepContacts({
    required Vector2 from,
    required Vector2 to,
    required double shotRadius,
    required Vector2 kidCenter,
    required double kidRadius,
  }) {
    final seg = to - from;
    final len2 = seg.length2;
    var t = 0.0;
    if (len2 > 1e-9) {
      t = ((kidCenter - from).dot(seg) / len2).clamp(0.0, 1.0);
    }
    return snowballContacts(
      ground: from + seg * t,
      shotRadius: shotRadius,
      kidCenter: kidCenter,
      kidRadius: kidRadius,
    );
  }

  /// Radians above horizontal after [clampAimDirection]. Positive is up.
  static double aimElevation(
    Vector2 aimDirection, {
    required bool facingRight,
  }) {
    final aim = clampAimDirection(aimDirection, facingRight: facingRight);
    return math.atan2(-aim.y, aim.x.abs());
  }

  /// Depth of a straight ground track [forward] pixels from its start.
  /// Positive [elevation] climbs up the screen (toward the back of the yard).
  static double trackYAt({
    required double startY,
    required double elevation,
    required double forward,
  }) {
    final clamped = elevation.clamp(-maxAimRadians, maxAimRadians);
    return startY - math.tan(clamped) * forward;
  }

  /// Ground-track depth band: the back and front lanes of the yard.
  static double clampTrackY(double y) =>
      y.clamp(ArenaGrid.laneY(0), ArenaGrid.laneY(ArenaGrid.rows - 1));

  /// How far a straight track at [elevation] misses [target] in depth,
  /// in pixels. Null when [target] is behind the thrower or out of [range].
  static double? trackMiss({
    required Vector2 start,
    required double elevation,
    required double range,
    required bool facingRight,
    required Vector2 target,
    double reachSlop = 0,
  }) {
    final forward = (target.x - start.x) * (facingRight ? 1 : -1);
    if (forward <= 0 || forward > range + reachSlop) return null;
    final y = clampTrackY(
      trackYAt(startY: start.y, elevation: elevation, forward: forward),
    );
    return target.y - y;
  }

  /// Elevation whose track passes through [target]. Clamped to the cone.
  static double elevationToward({
    required Vector2 start,
    required Vector2 target,
    required bool facingRight,
  }) {
    final forward = (target.x - start.x) * (facingRight ? 1 : -1);
    if (forward <= 1) return 0;
    final e = math.atan((start.y - target.y) / forward);
    return e.clamp(-maxAimRadians, maxAimRadians);
  }

  /// Player lob along the swept line.
  ///
  /// The ground track starts at the thrower's body height ([trackY], their
  /// hit center) and runs straight at the swept [aimDirection]. Charge sets
  /// how far it goes. [originY] is the hand, where the sprite leaves from.
  static RowLob planPlayerLob({
    required int throwerRow,
    required int throwerColumn,
    required Vector2 aimDirection,
    required double charge,
    required bool facingRight,
    double speedScale = 1,
    required double originY,
    double? trackY,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    final startY = trackY ?? originY;
    final elevation = aimElevation(aimDirection, facingRight: facingRight);
    final range = rangeForCharge(charge);
    final landingY = clampTrackY(
      trackYAt(startY: startY, elevation: elevation, forward: range),
    );
    final landing = ArenaGrid.rowForLaneY(landingY);
    final apexY = math.min(originY, landingY) - playerLoft;
    final scale = speedScale.clamp(0.2, 3.0);
    final speed = playerTravelSpeed * scale;
    final facing = facingRight ? 1.0 : -1.0;
    final loft = loftAt(0.5, range);
    return RowLob(
      velocity: Vector2(facing * speed, 0),
      throwerRow: row,
      throwerColumn: throwerColumn.clamp(0, ArenaGrid.columnsPerSide - 1),
      peakRow: math.min(row, landing),
      landingRow: landing,
      apexRise: loft < 1 ? 1 : loft,
      landingDrop: landingY - originY,
      range: range,
      groundTrack: true,
      travelSpeed: speed,
      originY: originY,
      trackY: startY,
      landingY: landingY,
      apexY: apexY,
      apexFraction: groundApexFraction,
      settleFraction: 1,
    );
  }

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

  /// Backyard floor on [landingRow]: just above that row's feet.
  /// A miss splats here. It stays on that row's ground, not the screen bottom,
  /// so a back-row lob does not fall to the front of the 3/4 yard.
  static double impactGroundY(int landingRow) {
    final row = landingRow.clamp(0, ArenaGrid.rows - 1);
    return ArenaGrid.rowY(row) - 16;
  }

  /// Drawn flight height. [collisionY] is the hit path.
  ///
  /// In the open yard the sprite follows a smooth lob from the hand toward
  /// the same landing the hit path commits to. Over a fort still ahead of
  /// the thrower, and once the ball reaches the target half, the drawn Y
  /// matches [collisionY] so splats line up with contact.
  static double flightVisualY({
    required double collisionY,
    required double worldX,
    required double originX,
    required double originY,
    required double range,
    required bool facingRight,
    required bool behindFort,
    required bool scripted,
    double apexY = 0,
    double landingY = 0,
    double apexFraction = 0.22,
    double settleFraction = 0.42,
  }) {
    if (range < 1) return collisionY;
    final dir = facingRight ? 1.0 : -1.0;
    final endX = _flightVisualEndX(
      originX: originX,
      range: range,
      facingRight: facingRight,
    );
    final span = (endX - originX) * dir;
    if (span < 36) return collisionY;
    final along = (worldX - originX) * dir;
    if (along <= 0 || along >= span) return collisionY;

    final t = along / span;
    final shaped = scripted
        ? _scriptedVisualY(
            t: t,
            span: span,
            originY: originY,
            endX: endX,
            originX: originX,
            range: range,
            facingRight: facingRight,
            apexY: apexY,
            landingY: landingY,
            apexFraction: apexFraction,
            settleFraction: settleFraction,
          )
        : collisionY - _visualHump(t, span);

    final lock = _fortVisualLock(
      worldX: worldX,
      facingRight: facingRight,
      behindFort: behindFort,
    );
    if (lock >= 1) return collisionY;
    if (lock <= 0) return shaped;
    return collisionY + (shaped - collisionY) * (1 - lock);
  }

  /// Where the drawn lob has to be back on the hit path: the planned
  /// landing, or just before the other side's half, whichever is closer.
  static double _flightVisualEndX({
    required double originX,
    required double range,
    required bool facingRight,
  }) {
    final dir = facingRight ? 1.0 : -1.0;
    final landingX = originX + dir * range;
    final approachX = facingRight
        ? ArenaGrid.enemyLeft - 48
        : ArenaGrid.playerRight + 48;
    if ((approachX - originX) * dir > 36) {
      return facingRight
          ? math.min(landingX, approachX)
          : math.max(landingX, approachX);
    }
    return landingX;
  }

  static double _scriptedVisualY({
    required double t,
    required double span,
    required double originY,
    required double endX,
    required double originX,
    required double range,
    required bool facingRight,
    required double apexY,
    required double landingY,
    required double apexFraction,
    required double settleFraction,
  }) {
    final dir = facingRight ? 1.0 : -1.0;
    final uEnd = ((endX - originX) * dir / range).clamp(0.0, 1.0);
    final yEnd = playerArcY(
      originY: originY,
      apexY: apexY,
      landingY: landingY,
      u: uEnd,
      apexFraction: apexFraction,
      settleFraction: settleFraction,
    );
    final s = t * t * (3 - 2 * t);
    final chord = originY + (yEnd - originY) * s;
    final y = chord - _visualHump(t, span);
    if (y < 28) return 28;
    return y;
  }

  /// Smooth hump: zero height and zero slope at both ends of the lob
  /// so it leaves the hand and joins the hit path without a corner.
  static double _visualHump(double t, double span) {
    final loft = (span.abs() * 0.22).clamp(40.0, 120.0);
    final s = math.sin(math.pi * t);
    return loft * s * s;
  }

  /// 1 while a shot from behind a fort is still over that fort, easing to 0
  /// just after it clears so the sprite can rise into the lob.
  static double _fortVisualLock({
    required double worldX,
    required bool facingRight,
    required bool behindFort,
  }) {
    if (!behindFort) return 0;
    final edges = _fortHorizontalEdges(playerSide: facingRight);
    final clearX = facingRight ? edges.$2 + 12 : edges.$1 - 12;
    final dir = facingRight ? 1.0 : -1.0;
    final past = (worldX - clearX) * dir;
    if (past <= 0) return 1;
    const blend = 72.0;
    if (past >= blend) return 0;
    final u = past / blend;
    final smooth = u * u * (3 - 2 * u);
    return 1 - smooth;
  }

  /// Horizontal fort footprint. Matches [ArenaGrid.fortFootprint] on X.
  /// Row does not move those edges. Kept here so throw math does not import
  /// the kid component (that import would cycle through combat rules).
  static (double, double) _fortHorizontalEdges({required bool playerSide}) {
    final leftEdge = playerSide ? ArenaGrid.playerLeft : ArenaGrid.enemyLeft;
    final rightEdge = playerSide ? ArenaGrid.playerRight : ArenaGrid.enemyRight;
    final step = ArenaGrid.columnStep;
    double x(int column) {
      final t = column / (ArenaGrid.columnsPerSide - 1);
      return leftEdge + (rightEdge - leftEdge) * t;
    }

    final a = x(ArenaGrid.coverColumnA);
    final b = x(ArenaGrid.coverColumnB);
    return (math.min(a, b) - step * 0.42, math.max(a, b) + step * 0.42);
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
  /// How far an enemy lob travels after scatter. Same clamp as [planEnemyLob].
  static double enemyLobRange({
    required double distance,
    required double rangeScale,
  }) {
    final scale = rangeScale.clamp(0.55, 1.45);
    return distance.abs().clamp(180.0, 1100.0) * scale;
  }

  /// True when that lob reaches [distance]. A short shot is the cue to step closer.
  static bool enemyLobReaches({
    required double distance,
    required double rangeScale,
  }) {
    final span = distance.abs();
    if (span < 8) return true;
    return enemyLobRange(distance: span, rangeScale: rangeScale) >= span - 8;
  }

  /// Bot lob. With [trackY] and [targetY] (body heights), the track is the
  /// straight line through the target, so a long throw still passes through
  /// them and a short one falls short in front. Without them it lands on
  /// [targetRow]'s lane.
  static RowLob planEnemyLob({
    required int throwerRow,
    required int throwerColumn,
    required int targetRow,
    required double distance,
    required double rangeScale,
    required bool facingRight,
    required double originY,
    double? trackY,
    double? targetY,
  }) {
    final row = throwerRow.clamp(0, ArenaGrid.rows - 1);
    final range = enemyLobRange(distance: distance, rangeScale: rangeScale);
    final facing = facingRight ? 1.0 : -1.0;
    final double landingY;
    if (trackY != null && targetY != null && distance.abs() > 1) {
      final slope = (targetY - trackY) / distance.abs();
      landingY = clampTrackY(trackY + slope * range);
    } else {
      landingY = ArenaGrid.laneY(targetRow.clamp(0, ArenaGrid.rows - 1));
    }
    final landing = ArenaGrid.rowForLaneY(landingY);
    final loft = loftAt(0.5, range);
    return RowLob(
      velocity: Vector2(facing * enemyTravelSpeed, 0),
      throwerRow: row,
      throwerColumn: throwerColumn.clamp(0, ArenaGrid.columnsPerSide - 1),
      peakRow: row,
      landingRow: landing,
      apexRise: loft < 1 ? 1 : loft,
      landingDrop: landingY - originY,
      range: range,
      groundTrack: true,
      travelSpeed: enemyTravelSpeed,
      originY: originY,
      trackY: trackY ?? originY,
      landingY: landingY,
      apexY: landingY,
      apexFraction: groundApexFraction,
      settleFraction: 1,
    );
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
  /// and never damage it. Opponent shots that are not at the peak damage a
  /// standing fort.
  static FortShotResult resolveFortShot({
    required bool overlaps,
    required bool atPeak,
    required bool sameSide,
    required bool throwerBehind,
    bool collapsed = false,
  }) {
    if (!overlaps || atPeak || collapsed) return FortShotResult.none;
    if (sameSide && !throwerBehind) return FortShotResult.none;
    if (sameSide) {
      return FortShotResult.blocked;
    }
    return FortShotResult.damaged;
  }

  /// Hard cap on rival stepping, in pixels per second.
  ///
  /// One column takes [stepSeconds]. Throw rank does not speed this up;
  /// difficulty applies its own scale on top in the match.
  static double kidMoveSpeed() {
    return ArenaGrid.columnStep / stepSeconds;
  }

  /// How much faster a finger drag is than that column walk.
  ///
  /// Playtest lock. Do not retune this. Six times the old column walk is
  /// the speed that felt right, on every difficulty.
  static const double dragSpeedScale = 6;

  /// Player drag. Six times the old cell walk, so a finger across the
  /// home half is easy to follow and a short move does not take a second.
  static double playerDragSpeed() => kidMoveSpeed() * dragSpeedScale;

  static double apexRise(Vector2 velocity) {
    if (velocity.y >= 0) return 0;
    return (velocity.y * velocity.y) / (2 * gravity);
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
