import 'dart:math' as math;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
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

    test(
      'charge anchors: tap is a third, one second is half, three seconds is full',
      () {
        const duration = 3.0;
        expect(
          ThrowPhysics.chargeForHold(0, duration),
          closeTo(ThrowPhysics.minThrowCharge, 0.001),
        );
        expect(
          ThrowPhysics.chargeForHold(0.12, duration),
          closeTo(1 / 3, 0.02),
        );
        expect(ThrowPhysics.chargeForHold(1, duration), closeTo(0.5, 0.03));
        expect(ThrowPhysics.chargeForHold(duration, duration), 1);
        expect(ThrowPhysics.chargeForHold(4, duration), 1);

        // The top half of the bar (1/2 → 1) takes the remaining two seconds.
        expect(ThrowPhysics.chargeForHold(0.85, duration), lessThan(0.5));
        expect(ThrowPhysics.chargeForHold(2, duration), greaterThan(0.5));
        expect(ThrowPhysics.chargeForHold(2, duration), lessThan(1));

        double step(double t) {
          const dt = 0.25;
          return ThrowPhysics.chargeForHold(t + dt, duration) -
              ThrowPhysics.chargeForHold(t, duration);
        }

        // Past the halfway mark the half-bell keeps slowing down.
        expect(step(1.1), greaterThan(step(1.8)));
        expect(step(1.8), greaterThan(step(2.5)));
      },
    );

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

    test(
      'a steep tap climbs more rows than a flat throw at the same power',
      () {
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          ArenaGrid.cellCenter(KidSide.player, 1, 4),
          Vector2.all(152),
        );
        RowLob throwAt(Vector2 aim, double charge) {
          return ThrowPhysics.planPlayerLob(
            throwerRow: 4,
            throwerColumn: 1,
            aimDirection: aim,
            charge: charge,
            facingRight: true,
            originY: from.y,
          );
        }

        final flat = throwAt(Vector2(1, 0), ThrowPhysics.minThrowCharge);
        final steep = throwAt(Vector2(0, -1), ThrowPhysics.minThrowCharge);
        final fullFlat = throwAt(Vector2(1, 0), 1);
        final fullSteep = throwAt(Vector2(0, -1), 1);
        expect(flat.landingRow, 4);
        expect(fullFlat.landingRow, 4);
        expect(steep.landingRow, lessThan(flat.landingRow));
        expect(fullSteep.landingRow, lessThan(steep.landingRow));
        expect(steep.velocity.x, closeTo(flat.velocity.x, 0.01));
        expect(steep.range, closeTo(flat.range, 0.01));
        expect(steep.rowAt(1), steep.landingRow);
        expect(
          ThrowPhysics.playerCanHit(
            landingRow: steep.landingRow,
            shotRow: steep.rowAt(1),
            targetRow: steep.landingRow,
          ),
          isTrue,
        );
        expect(
          ThrowPhysics.playerCanHit(
            landingRow: steep.landingRow,
            shotRow: steep.rowAt(1),
            targetRow: steep.landingRow + 1,
          ),
          isFalse,
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
          ThrowPhysics.aimElevation(Vector2(0.2, -1), facingRight: true),
          lessThanOrEqualTo(ThrowPhysics.maxAimRadians + 0.001),
        );
        expect(ThrowPhysics.maxAimRadians, closeTo(20 * math.pi / 180, 1e-9));
        final aim01 =
            ThrowPhysics.maxAimRadians / ThrowPhysics.aimRowScaleRadians;
        expect(aim01, lessThan(0.5));
        expect(
          (4 - fullSteep.landingRow).abs(),
          lessThanOrEqualTo((ThrowPhysics.aimRowsAtFull * aim01).ceil()),
        );
        expect((4 - fullSteep.landingRow).abs(), lessThan(3));
      },
    );

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
      expect(ThrowPhysics.loftAt(0.5, lob.range), greaterThan(40));
      expect(ThrowPhysics.loftAt(0, lob.range), closeTo(0, 0.001));
      expect(ThrowPhysics.loftAt(1, lob.range), closeTo(0, 0.001));
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
      'charge swivel swings the cone and release timing picks the depth',
      () {
        expect(ThrowPhysics.swivelPeriod, closeTo(3.6, 0.001));
        expect(ThrowPhysics.swivelElevation(0), closeTo(0, 0.001));
        expect(
          ThrowPhysics.swivelElevation(ThrowPhysics.swivelPeriod / 4),
          closeTo(ThrowPhysics.maxAimRadians, 0.001),
        );
        expect(
          ThrowPhysics.swivelElevation(ThrowPhysics.swivelPeriod / 2),
          closeTo(0, 0.001),
        );
        expect(
          ThrowPhysics.swivelElevation(ThrowPhysics.swivelPeriod * 0.75),
          closeTo(-ThrowPhysics.maxAimRadians, 0.001),
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians),
          ChargeYaw.back,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.5),
          ChargeYaw.back,
        );
        expect(
          ThrowPhysics.chargeYaw(ThrowPhysics.maxAimRadians * 0.49),
          ChargeYaw.across,
        );
        expect(ThrowPhysics.chargeYaw(0), ChargeYaw.across);
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.01),
          ChargeYaw.quarter,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.5),
          ChargeYaw.quarter,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians * 0.51),
          ChargeYaw.front,
        );
        expect(
          ThrowPhysics.chargeYaw(-ThrowPhysics.maxAimRadians),
          ChargeYaw.front,
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
