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

    test('a lob stays inside the thrower row lane', () {
      const size = 152.0;
      final sprite = Vector2.all(size);
      for (var row = 0; row < ArenaGrid.rows; row++) {
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          ArenaGrid.cellCenter(KidSide.player, 0, row),
          sprite,
        );
        for (final charge in [1 / 3, 0.5, 1.0]) {
          for (final aim in [row - 1, row, row + 1]) {
            final lob = ThrowPhysics.planPlayerLob(
              throwerRow: row,
              throwerColumn: 0,
              aimRow: aim,
              charge: charge,
              facingRight: true,
              originY: from.y,
            );
            expect(lob.peakRow, greaterThanOrEqualTo(row - 1));
            expect(lob.peakRow, lessThanOrEqualTo(row));
            expect(lob.peakRow, inInclusiveRange(0, ArenaGrid.rows - 1));
            expect((lob.landingRow - row).abs(), lessThanOrEqualTo(1));
            expect(lob.landingRow, inInclusiveRange(0, ArenaGrid.rows - 1));
            _fly(lob, from, (x, y, vy, shotRow) {
              expect(
                (shotRow - row).abs(),
                lessThanOrEqualTo(1),
                reason: 'row $row charge $charge drifted to $shotRow',
              );
            });
          }
        }
      }
    });

    test(
      'full power sails over a same-row target and a tap lands short below',
      () {
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          ArenaGrid.cellCenter(KidSide.player, 1, 4),
          Vector2.all(152),
        );
        final full = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 1,
          aimRow: 4,
          charge: 1,
          facingRight: true,
          originY: from.y,
        );
        expect(full.peakRow, 3);
        expect(full.landingRow, 4);
        expect(full.range, greaterThan(800));
        var sailedOver = false;
        var cameDown = false;
        _fly(full, from, (x, y, vy, shotRow) {
          final along = x - from.x;
          if (shotRow == 3 &&
              along > full.range * 0.25 &&
              along < full.range * 0.8) {
            sailedOver = true;
          }
          if (shotRow == 4 && along > full.range * 0.85) cameDown = true;
        });
        expect(sailedOver, isTrue);
        expect(cameDown, isTrue);

        final tap = ThrowPhysics.planPlayerLob(
          throwerRow: 4,
          throwerColumn: 1,
          aimRow: 4,
          charge: ThrowPhysics.minThrowCharge,
          facingRight: true,
          originY: from.y,
        );
        expect(tap.peakRow, 4);
        expect(tap.landingRow, 5);
        expect(tap.range, lessThan(full.range * 0.4));
      },
    );

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
    });

    test(
      'a short lob from behind the fort can peak over it; full power cannot',
      () {
        final feet = ArenaGrid.cellCenter(KidSide.player, 0, 4);
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          feet,
          Vector2.all(152),
        );
        final box = ArenaGrid.fortFootprint(KidSide.player);
        double apexFor(double charge) {
          final lob = ThrowPhysics.planPlayerLob(
            throwerRow: 4,
            throwerColumn: 0,
            aimRow: 4,
            charge: charge,
            facingRight: true,
            originY: from.y,
          );
          return ThrowPhysics.apexX(
            originX: from.x,
            velocity: lob.velocity,
            launchVy: lob.velocity.y,
          );
        }

        final tapApex = apexFor(ThrowPhysics.minThrowCharge);
        final fullApex = apexFor(1);
        expect(tapApex, inInclusiveRange(box.left, box.right));
        expect(fullApex, greaterThan(box.right));
        expect(ArenaGrid.columnIsBehindFort(KidSide.player, 0), isTrue);
        expect(ArenaGrid.columnIsBehindFort(KidSide.player, 1), isFalse);
      },
    );

    test('a full-power lob is flatter than a steep flick', () {
      final shot = ThrowPhysics.launchVelocity(
        charge: 1,
        aimDirection: Vector2(1, -0.9),
      );
      final loft = math.atan2(-shot.y, shot.x);
      expect(loft, lessThan(32 * math.pi / 180));
      expect(shot.x, greaterThan(shot.y.abs()));
    });

    test('kid move speed stays at or under projectile speed', () {
      final shot = ThrowPhysics.planPlayerLob(
        throwerRow: 4,
        throwerColumn: 0,
        aimRow: 4,
        charge: 1,
        facingRight: true,
        speedScale: 1.35,
        originY: ArenaGrid.laneY(4) - ArenaGrid.kidSize * 0.1,
      );
      final pace = ThrowPhysics.kidMoveSpeed(speedScale: 1.35);
      expect(pace, lessThanOrEqualTo(shot.velocity.length + 0.001));
      expect(pace, closeTo(shot.velocity.x.abs(), 0.001));
      expect(pace, greaterThan(200));
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

void _fly(
  RowLob lob,
  Vector2 from,
  void Function(double x, double y, double vy, int row) sample,
) {
  var x = from.x;
  var y = from.y;
  var vy = lob.velocity.y;
  final vx = lob.velocity.x;
  const dt = 1 / 120;
  for (var i = 0; i < 120 * 4; i++) {
    vy += ThrowPhysics.gravity * dt;
    x += vx * dt;
    y += vy * dt;
    final row = ThrowPhysics.lobRow(
      throwerRow: lob.throwerRow,
      peakRow: lob.peakRow,
      landingRow: lob.landingRow,
      originY: from.y,
      apexRise: lob.apexRise,
      landingDrop: lob.landingDrop,
      y: y,
      vy: vy,
    );
    sample(x, y, vy, row);
    if ((x - from.x).abs() > lob.range + 20) return;
  }
}
