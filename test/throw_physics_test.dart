import 'dart:math' as math;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThrowPhysics', () {
    test('launchVelocity scales with charge and goes upward', () {
      final slow = ThrowPhysics.launchVelocity(
        charge: 0.2,
        aimDirection: Vector2(1, -0.4),
      );
      final fast = ThrowPhysics.launchVelocity(
        charge: 1.0,
        aimDirection: Vector2(1, -0.4),
      );
      expect(fast.length, greaterThan(slow.length));
      expect(slow.y, lessThan(0));
      expect(fast.x, greaterThan(0));
    });

    test('circlesOverlap detects hit and miss', () {
      expect(
        ThrowPhysics.circlesOverlap(Vector2(0, 0), 10, Vector2(15, 0), 10),
        isTrue,
      );
      expect(
        ThrowPhysics.circlesOverlap(Vector2(0, 0), 10, Vector2(50, 0), 10),
        isFalse,
      );
    });

    test('defaultAim biases upward toward target', () {
      final aim = ThrowPhysics.defaultAim(Vector2(0, 0), Vector2(200, 0));
      expect(aim.x, greaterThan(0));
      expect(aim.y, lessThan(0));
    });

    test('enemy lobs keep a leftward upward arc', () {
      final velocity = ThrowPhysics.launchVelocity(
        charge: 1,
        aimDirection: Vector2(-1, 0.2),
      );
      expect(velocity.x, lessThan(0));
      expect(velocity.y, lessThan(0));
    });

    test('charge starts at the tap minimum and climbs steadily to full', () {
      const duration = 3.0;
      const min = ThrowPhysics.minThrowCharge;
      expect(ThrowPhysics.chargeForHold(0, duration), closeTo(min, 1e-9));
      // No plateau: the bar is already moving a tenth of a second in.
      expect(ThrowPhysics.chargeForHold(0.1, duration), greaterThan(min));
      expect(
        ThrowPhysics.chargeForHold(1, duration),
        closeTo(min + (1 - min) / 3, 1e-9),
      );
      expect(ThrowPhysics.chargeForHold(duration, duration), 1);
      expect(ThrowPhysics.chargeForHold(4, duration), 1);

      double step(double t) {
        const dt = 0.25;
        return ThrowPhysics.chargeForHold(t + dt, duration) -
            ThrowPhysics.chargeForHold(t, duration);
      }

      // Same rate the whole way up.
      expect(step(0), closeTo(step(1.2), 1e-9));
      expect(step(1.2), closeTo(step(2.5), 1e-9));
    });

    test(
      'the aim sweep pans at a constant speed with no pause at the ends',
      () {
        const quarter = math.pi / 2;
        expect(ThrowPhysics.sweepWave(0), closeTo(0, 1e-9));
        expect(ThrowPhysics.sweepWave(quarter), closeTo(1, 1e-9));
        expect(ThrowPhysics.sweepWave(2 * quarter), closeTo(0, 1e-9));
        expect(ThrowPhysics.sweepWave(3 * quarter), closeTo(-1, 1e-9));
        expect(ThrowPhysics.sweepWave(4 * quarter), closeTo(0, 1e-9));
        // Equal phase steps move the same distance, right up to the turn.
        const d = 0.1;
        final mid = ThrowPhysics.sweepWave(d) - ThrowPhysics.sweepWave(0);
        final nearEnd =
            ThrowPhysics.sweepWave(quarter) -
            ThrowPhysics.sweepWave(quarter - d);
        expect(nearEnd, closeTo(mid, 1e-9));
      },
    );

    test('preview detail drops with difficulty', () {
      expect(Difficulty.easy.aimPreview, AimPreview.full);
      expect(Difficulty.normal.aimPreview, AimPreview.path);
      expect(Difficulty.hard.aimPreview, AimPreview.none);
    });

    test('full power reaches the enemy half and a tap does not', () {
      final size = Vector2(152, 152);
      final from = ArenaGrid.throwOrigin(
        KidSide.player,
        ArenaGrid.cellCenter(KidSide.player, 0, 0),
        size,
      );
      final far = ArenaGrid.hitCenter(
        ArenaGrid.cellCenter(KidSide.enemy, ArenaGrid.columnsPerSide - 1, 7),
        size,
      );
      final maxSpeed = ThrowPhysics.speedForCharge(1);
      expect(
        ThrowPhysics.launchToward(from: from, to: far, speed: maxSpeed),
        isNotNull,
      );
      final tap = ThrowPhysics.speedForCharge(0.15);
      expect(
        ThrowPhysics.launchToward(from: from, to: far, speed: tap),
        isNull,
      );
    });

    test('full power reaches the far side without speeding the ball up', () {
      final from = ArenaGrid.throwOrigin(
        KidSide.player,
        ArenaGrid.cellCenter(KidSide.player, 0, 4),
        Vector2.all(152),
      );
      final full = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 0,
        aimDirection: Vector2(1, 0),
        charge: 1,
        facingRight: true,
        originY: from.y,
      );
      final tap = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 0,
        aimDirection: Vector2(1, 0),
        charge: ThrowPhysics.minThrowCharge,
        facingRight: true,
        originY: from.y,
      );
      expect(full.groundTrack, isTrue);
      expect(full.scripted, isFalse);
      expect(
        from.x + full.range,
        greaterThanOrEqualTo(ThrowPhysics.yardFarEdge),
      );
      expect(full.velocity.x, closeTo(ThrowPhysics.playerTravelSpeed, 0.01));
      expect(tap.velocity.x, closeTo(full.velocity.x, 0.01));
      expect(tap.range, lessThan(full.range * 0.35));
      final tapEnd = from.x + tap.range;
      expect(tapEnd, greaterThan(ArenaGrid.playerRight));
      expect(tapEnd, lessThan(ArenaGrid.enemyLeft));
    });

    test('the swept angle is the ground track, and charge sets how far', () {
      final trackY = ArenaGrid.laneY(4);
      RowLob throwAt(Vector2 aim, double charge) {
        return ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 1,
          aimDirection: aim,
          charge: charge,
          facingRight: true,
          originY: trackY - 15,
          trackY: trackY,
        );
      }

      final flat = throwAt(Vector2(1, 0), ThrowPhysics.minThrowCharge);
      final steep = throwAt(Vector2(0, -1), ThrowPhysics.minThrowCharge);
      final fullFlat = throwAt(Vector2(1, 0), 1);
      final fullSteep = throwAt(Vector2(0, -1), 1);
      expect(flat.landingRow, 4);
      expect(fullFlat.landingRow, 4);
      expect(flat.landingY, closeTo(trackY, 0.01));
      expect(steep.landingRow, lessThan(flat.landingRow));
      expect(fullSteep.landingY, lessThan(steep.landingY));
      expect(steep.velocity.x, closeTo(flat.velocity.x, 0.01));
      expect(steep.range, closeTo(flat.range, 0.01));
      expect(steep.trackY, closeTo(trackY, 0.01));

      // Depth is continuous: the track drifts tan(elevation) per pixel and
      // is not rounded to a lane.
      final aim = ThrowPhysics.maxAimRadians * 0.37;
      final partial = throwAt(
        ThrowPhysics.aimForElevation(aim, facingRight: true),
        ThrowPhysics.minThrowCharge,
      );
      expect(
        partial.landingY,
        closeTo(trackY - math.tan(aim) * partial.range, 0.01),
      );
      expect(
        ThrowPhysics.trackYAt(startY: 500, elevation: aim, forward: 300),
        closeTo(500 - math.tan(aim) * 300, 1e-9),
      );

      expect(
        ThrowPhysics.aimElevation(Vector2(0, -1), facingRight: true),
        closeTo(ThrowPhysics.maxAimRadians, 0.001),
      );
      expect(
        ThrowPhysics.aimElevation(Vector2(0, 1), facingRight: true),
        closeTo(-ThrowPhysics.maxAimRadians, 0.001),
      );
      expect(
        ThrowPhysics.aimElevation(Vector2(1, 0), facingRight: true).abs(),
        lessThan(0.001),
      );
      expect(
        math.tan(ThrowPhysics.maxAimRadians),
        closeTo(ThrowPhysics.maxAimSlope, 1e-9),
      );
    });

    test('a full sweep covers the rival half from mid-yard', () {
      final start = Vector2(300, ArenaGrid.laneY(4));
      const forward = 700.0;
      final up = ThrowPhysics.trackYAt(
        startY: start.y,
        elevation: ThrowPhysics.maxAimRadians,
        forward: forward,
      );
      final down = ThrowPhysics.trackYAt(
        startY: start.y,
        elevation: -ThrowPhysics.maxAimRadians,
        forward: forward,
      );
      expect(up, lessThanOrEqualTo(ArenaGrid.laneY(0) + ArenaGrid.rowStep));
      expect(
        down,
        greaterThanOrEqualTo(
          ArenaGrid.laneY(ArenaGrid.rows - 1) - ArenaGrid.rowStep,
        ),
      );
    });

    test('trackMiss and elevationToward agree on a rival', () {
      final start = Vector2(300, ArenaGrid.laneY(4));
      final rival = Vector2(1000, ArenaGrid.laneY(2) + 7);
      final e = ThrowPhysics.elevationToward(
        start: start,
        target: rival,
        facingRight: true,
      );
      final miss = ThrowPhysics.trackMiss(
        start: start,
        elevation: e,
        range: 2000,
        facingRight: true,
        target: rival,
      );
      expect(miss, isNotNull);
      expect(miss!.abs(), lessThan(0.01));
      expect(
        ThrowPhysics.trackMiss(
          start: start,
          elevation: e,
          range: 500,
          facingRight: true,
          target: rival,
        ),
        isNull,
        reason: 'out of reach',
      );
      expect(
        ThrowPhysics.trackMiss(
          start: start,
          elevation: e,
          range: 2000,
          facingRight: false,
          target: rival,
        ),
        isNull,
        reason: 'behind the thrower',
      );
    });

    test('a fast ball cannot step over a kid in one frame', () {
      final kid = Vector2(600, 500);
      const r = 22.0;
      const kidR = 24.0;
      // Two samples 200px apart straddle the kid. Neither touches alone.
      final before = Vector2(490, 500);
      final after = Vector2(690, 500);
      expect(
        ThrowPhysics.snowballContacts(
          ground: before,
          shotRadius: r,
          kidCenter: kid,
          kidRadius: kidR,
        ),
        isFalse,
      );
      expect(
        ThrowPhysics.snowballContacts(
          ground: after,
          shotRadius: r,
          kidCenter: kid,
          kidRadius: kidR,
        ),
        isFalse,
      );
      expect(
        ThrowPhysics.snowballSweepContacts(
          from: before,
          to: after,
          shotRadius: r,
          kidCenter: kid,
          kidRadius: kidR,
        ),
        isTrue,
      );
      // A whole row off still passes in front.
      expect(
        ThrowPhysics.snowballSweepContacts(
          from: before + Vector2(0, ArenaGrid.rowStep),
          to: after + Vector2(0, ArenaGrid.rowStep),
          shotRadius: r,
          kidCenter: kid,
          kidRadius: kidR,
        ),
        isFalse,
      );
    });

    test('a rival lob runs through the target, so a long throw still hits', () {
      final trackY = ArenaGrid.laneY(3);
      final targetY = ArenaGrid.laneY(5) + 9;
      const distance = 600.0;
      final lob = ThrowPhysics.planEnemyLob(
        throwerRow: 3,
        throwerColumn: 1,
        targetRow: 5,
        distance: distance,
        rangeScale: 1.3,
        facingRight: false,
        originY: trackY - 15,
        trackY: trackY,
        targetY: targetY,
      );
      expect(lob.range, greaterThan(distance));
      final u = distance / lob.range;
      expect(lob.yAt(u), closeTo(targetY, 0.01));
    });

    test('a player lob keeps its pace and slides to the aimed depth', () {
      final from = ArenaGrid.throwOrigin(
        KidSide.player,
        ArenaGrid.cellCenter(KidSide.player, 0, 4),
        Vector2.all(152),
      );
      final lob = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 0,
        aimDirection: Vector2(1, -0.35),
        charge: 1,
        facingRight: true,
        originY: from.y,
      );
      expect(
        lob.velocity.x.abs(),
        closeTo(ThrowPhysics.playerTravelSpeed, 0.01),
      );
      var previousX = from.x;
      for (var i = 1; i <= 20; i++) {
        final u = i / 20.0;
        final x = from.x + lob.range * u;
        final y = lob.yAt(u);
        final row = lob.rowAt(u);
        expect(x, greaterThan(previousX));
        expect(y, inInclusiveRange(1, 719));
        final low = math.min(4, lob.landingRow);
        final high = math.max(4, lob.landingRow);
        expect(row, inInclusiveRange(low, high));
        if (u >= 1) {
          expect(row, lob.landingRow);
          expect(y, closeTo(lob.landingY, 0.01));
        }
        previousX = x;
      }
      expect(ThrowPhysics.loftAt(0.5, lob.range), ThrowPhysics.visualLoftPeak);
      expect(ThrowPhysics.loftAt(0, lob.range), closeTo(0, 0.001));
      expect(ThrowPhysics.loftAt(1, lob.range), closeTo(0, 0.001));
    });

    test('a lob climbs and drops without swapping up-aim and down-aim', () {
      final short = ThrowPhysics.loftAt(0.5, 200);
      final long = ThrowPhysics.loftAt(0.5, 1000);
      expect(short, ThrowPhysics.visualLoftPeak);
      expect(long, short);
      expect(short, greaterThan(48));
      expect(short, lessThan(96));
      expect(ThrowPhysics.loftAt(0, 1000), closeTo(0, 0.001));
      expect(ThrowPhysics.loftAt(1, 1000), closeTo(0, 0.001));
      expect(ThrowPhysics.loftAt(0.25, 800), lessThan(short));
      expect(ThrowPhysics.loftAt(0.25, 800), greaterThan(0));

      final originY = ArenaGrid.laneY(4);
      final up = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 1,
        aimDirection: ThrowPhysics.aimForElevation(
          ThrowPhysics.maxAimRadians,
          facingRight: true,
        ),
        charge: 1,
        facingRight: true,
        originY: originY,
      );
      final down = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 1,
        aimDirection: ThrowPhysics.aimForElevation(
          -ThrowPhysics.maxAimRadians,
          facingRight: true,
        ),
        charge: 1,
        facingRight: true,
        originY: originY,
      );
      final flat = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 1,
        aimDirection: Vector2(1, 0),
        charge: 1,
        facingRight: true,
        originY: originY,
      );
      expect(up.groundTrack, isTrue);
      expect(down.groundTrack, isTrue);
      expect(down.landingY, greaterThan(up.landingY));
      expect(down.yAt(0.5), greaterThan(up.yAt(0.5)));
      expect(up.yAt(0.5), closeTo((up.originY + up.landingY) / 2, 0.01));

      double drawn(RowLob lob, double u) {
        return ThrowPhysics.drawnLobY(
          originY: lob.originY,
          landingY: lob.landingY,
          u: u,
          range: lob.range,
        );
      }

      expect(drawn(flat, 0), closeTo(flat.originY, 0.01));
      expect(drawn(flat, 1), closeTo(flat.landingY, 0.01));
      expect(
        flat.originY - drawn(flat, 0.5),
        closeTo(ThrowPhysics.visualLoftPeak, 0.01),
      );
      expect(drawn(flat, 0.2), lessThan(flat.originY));
      expect(drawn(flat, 0.8), greaterThan(drawn(flat, 0.5)));

      final upDrawn = drawn(up, 0.5);
      final downDrawn = drawn(down, 0.5);
      expect(downDrawn, greaterThan(upDrawn));
      expect(downDrawn - upDrawn, closeTo(down.yAt(0.5) - up.yAt(0.5), 0.001));
      expect(upDrawn, lessThan(up.originY));
      expect(drawn(down, 0.85), greaterThan(down.originY));
      expect(drawn(up, 0.85), lessThan(drawn(down, 0.85)));
    });

    test('a short enemy lob is the cue to step closer', () {
      expect(
        ThrowPhysics.enemyLobReaches(distance: 700, rangeScale: 1),
        isTrue,
      );
      expect(
        ThrowPhysics.enemyLobReaches(distance: 700, rangeScale: 0.62),
        isFalse,
      );
      expect(
        ThrowPhysics.enemyLobReaches(distance: 1200, rangeScale: 1),
        isFalse,
      );
    });

    test('enemy lobs stay on the fast ballistic lane', () {
      final enemy = ThrowPhysics.planEnemyLob(
        throwerRow: 4,
        throwerColumn: 2,
        targetRow: 4,
        distance: 720,
        rangeScale: 1,
        facingRight: false,
        originY: ArenaGrid.laneY(4),
      );
      expect(enemy.scripted, isFalse);
      expect(enemy.landingRow, 4);
      expect((enemy.peakRow - 4).abs(), lessThanOrEqualTo(1));
      expect(
        enemy.velocity.x.abs(),
        greaterThan(ThrowPhysics.playerTravelSpeed * 1.2),
      );
    });

    test('fort shots clear only at the peak and friendly damage is opt-in', () {
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: true,
          sameSide: true,
          throwerBehind: true,
          friendlyDamage: false,
        ),
        FortShotResult.none,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: true,
          throwerBehind: true,
          friendlyDamage: false,
        ),
        FortShotResult.blocked,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: true,
          throwerBehind: true,
          friendlyDamage: true,
        ),
        FortShotResult.damaged,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: true,
          throwerBehind: false,
          friendlyDamage: true,
        ),
        FortShotResult.none,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: false,
          throwerBehind: false,
          friendlyDamage: false,
        ),
        FortShotResult.damaged,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: true,
          sameSide: false,
          throwerBehind: false,
          friendlyDamage: false,
        ),
        FortShotResult.none,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: true,
          throwerBehind: true,
          friendlyDamage: false,
          collapsed: true,
        ),
        FortShotResult.none,
      );
      expect(
        ThrowPhysics.resolveFortShot(
          overlaps: true,
          atPeak: false,
          sameSide: false,
          throwerBehind: false,
          friendlyDamage: false,
          collapsed: true,
        ),
        FortShotResult.none,
      );
    });

    test('a lob from behind the fort peaks past it', () {
      final feet = ArenaGrid.cellCenter(KidSide.player, 0, 4);
      final from = ArenaGrid.throwOrigin(
        KidSide.player,
        feet,
        Vector2.all(152),
      );
      final box = ArenaGrid.fortFootprint(KidSide.player);
      final enemy = ArenaGrid.fortFootprint(KidSide.enemy);
      double apexFor(double charge) {
        final lob = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 0,
          aimDirection: Vector2(1, 0),
          charge: charge,
          facingRight: true,
          originY: from.y,
        );
        return lob.apexWorldX(from.x);
      }

      final tapApex = apexFor(ThrowPhysics.minThrowCharge);
      final fullApex = apexFor(1);
      expect(box.width, lessThan(ArenaGrid.horizontalSpan * 0.5));
      expect(
        ThrowPhysics.peaksPastFort(
          apexX: tapApex,
          footprint: box,
          facingRight: true,
        ),
        isTrue,
      );
      expect(
        ThrowPhysics.peaksPastFort(
          apexX: fullApex,
          footprint: box,
          facingRight: true,
        ),
        isTrue,
      );
      expect(
        ThrowPhysics.peaksPastFort(
          apexX: fullApex,
          footprint: enemy,
          facingRight: true,
        ),
        isFalse,
      );
      expect(ArenaGrid.columnIsBehindFort(KidSide.player, 0), isTrue);
      expect(ArenaGrid.columnIsBehindFort(KidSide.player, 1), isFalse);
    });

    test('a full-power lob is flatter than a steep flick', () {
      final shot = ThrowPhysics.launchVelocity(
        charge: 1,
        aimDirection: Vector2(1, -0.9),
      );
      final loft = math.atan2(-shot.y, shot.x);
      expect(loft, lessThan(32 * math.pi / 180));
      expect(shot.x, greaterThan(shot.y.abs()));
    });

    test('walk cap is one column per step and stays under throw pace', () {
      final pace = ThrowPhysics.kidMoveSpeed();
      expect(
        pace,
        closeTo(ArenaGrid.columnStep / ThrowPhysics.stepSeconds, 0.01),
      );
      expect(ThrowPhysics.stepSeconds, closeTo(1.2, 0.001));
      expect(
        ThrowPhysics.playerDragSpeed(),
        closeTo(pace * ThrowPhysics.dragSpeedScale, 0.01),
      );
      expect(ThrowPhysics.dragSpeedScale, 6);
      expect(pace, lessThan(ThrowPhysics.playerTravelSpeed));
      expect(pace, lessThan(80));
      expect(pace, greaterThan(40));
      final ranked = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 0,
        aimDirection: Vector2(1, 0),
        charge: 1,
        facingRight: true,
        speedScale: 1.35,
        originY: ArenaGrid.laneY(4),
      );
      expect(
        ranked.velocity.x.abs(),
        closeTo(ThrowPhysics.playerTravelSpeed * 1.35, 0.01),
      );
      expect(ranked.range, closeTo(ThrowPhysics.fullRange, 0.01));
    });

    test(
      'a drawn lob arches in the open and meets the hit path at contact',
      () {
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          ArenaGrid.cellCenter(KidSide.player, 0, 4),
          Vector2.all(152),
        );
        final lob = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 0,
          aimDirection: Vector2(1, 0),
          charge: 1,
          facingRight: true,
          originY: from.y,
        );
        double collisionAt(double x) {
          final u = ((x - from.x) / lob.range).clamp(0.0, 1.0);
          return lob.yAt(u);
        }

        double visualAt(double x) {
          return ThrowPhysics.flightVisualY(
            collisionY: collisionAt(x),
            worldX: x,
            originX: from.x,
            originY: from.y,
            range: lob.range,
            facingRight: true,
            behindFort: true,
            scripted: true,
            apexY: lob.apexY,
            landingY: lob.landingY,
            apexFraction: lob.apexFraction,
            settleFraction: lob.settleFraction,
          );
        }

        final fort = ArenaGrid.fortFootprint(KidSide.player);
        final fortX = (fort.left + fort.right) / 2;
        expect(visualAt(fortX), closeTo(collisionAt(fortX), 0.01));
        expect(visualAt(from.x), closeTo(collisionAt(from.x), 0.01));

        final mid = (from.x + ArenaGrid.enemyLeft) / 2;
        expect(visualAt(mid), lessThan(collisionAt(mid) - 36));

        final contactX = ArenaGrid.enemyLeft + 8;
        expect(visualAt(contactX), closeTo(collisionAt(contactX), 0.01));
        expect(visualAt(from.x + lob.range), closeTo(lob.landingY, 0.01));
      },
    );

    test('an enemy lob arches across the yard and is back on the hit path', () {
      final originX = ArenaGrid.columnX(KidSide.enemy, 3) - 20;
      final originY = ArenaGrid.laneY(4);
      const range = 780.0;
      double visualAt(double x) {
        return ThrowPhysics.flightVisualY(
          collisionY: originY,
          worldX: x,
          originX: originX,
          originY: originY,
          range: range,
          facingRight: false,
          behindFort: true,
          scripted: false,
        );
      }

      final open = (originX + ArenaGrid.playerRight) / 2;
      expect(visualAt(open), lessThan(originY - 24));
      expect(visualAt(ArenaGrid.playerRight - 12), closeTo(originY, 0.01));
      expect(visualAt(originX), closeTo(originY, 0.01));
    });

    test(
      'charge yaw follows the cone and release elevation picks the depth',
      () {
        expect(ThrowPhysics.swivelPeriod, closeTo(3.6, 0.001));
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians),
          ChargeYaw.yaw30l,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.6),
          ChargeYaw.yaw30l,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.59),
          ChargeYaw.yaw15l,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.2),
          ChargeYaw.yaw15l,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.19),
          ChargeYaw.across,
        );
        expect(ThrowPhysics.chargeYaw(0), ChargeYaw.across);
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.2),
          ChargeYaw.across,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.21),
          ChargeYaw.yaw15r,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.6),
          ChargeYaw.yaw15r,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.61),
          ChargeYaw.yaw30r,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians),
          ChargeYaw.yaw30r,
        );
        final up = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 1,
          aimDirection: ThrowPhysics.aimForElevation(
            ThrowPhysics.maxAimRadians,
            facingRight: true,
          ),
          charge: 1,
          facingRight: true,
          originY: ArenaGrid.laneY(4),
        );
        final down = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 1,
          aimDirection: ThrowPhysics.aimForElevation(
            -ThrowPhysics.maxAimRadians,
            facingRight: true,
          ),
          charge: 1,
          facingRight: true,
          originY: ArenaGrid.laneY(4),
        );
        expect(up.landingRow, lessThan(4));
        expect(down.landingRow, greaterThan(4));
      },
    );

    test('a small depth window lets a ball pass in front or behind', () {
      final kid = Vector2(400, ArenaGrid.laneY(4));
      const shot = 22.0;
      final body = ArenaGrid.kidSize * ThrowPhysics.kidHitScale;
      expect(
        ThrowPhysics.snowballContacts(
          ground: Vector2(400, kid.y),
          shotRadius: shot,
          kidCenter: kid,
          kidRadius: body,
        ),
        isTrue,
      );
      final window = ArenaGrid.rowStep * ThrowPhysics.depthWindowFraction;
      expect(
        ThrowPhysics.snowballContacts(
          ground: Vector2(400, kid.y + window + 4),
          shotRadius: shot,
          kidCenter: kid,
          kidRadius: body,
        ),
        isFalse,
      );
      expect(
        ThrowPhysics.snowballContacts(
          ground: Vector2(400 + shot + body + 8, kid.y),
          shotRadius: shot,
          kidCenter: kid,
          kidRadius: body,
        ),
        isFalse,
      );
    });

    test('a miss lands on that row’s feet, not the bottom of the screen', () {
      final ground = ThrowPhysics.impactGroundY(4);
      expect(ground, greaterThan(ArenaGrid.laneY(4)));
      expect(ground, lessThan(ArenaGrid.rowY(4)));
      expect(ground, lessThan(700));
    });

    test('speedScale multiplies launch speed', () {
      final slow = ThrowPhysics.launchVelocity(
        charge: 0.5,
        aimDirection: Vector2(1, -0.4),
      );
      final fast = ThrowPhysics.launchVelocity(
        charge: 0.5,
        aimDirection: Vector2(1, -0.4),
        speedScale: 2,
      );
      expect(fast.length, closeTo(slow.length * 2, 0.001));
    });
  });
}
