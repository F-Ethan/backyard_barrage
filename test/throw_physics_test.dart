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

    test('charge fills fast at first and slower as the hold continues', () {
      const duration = 0.85;
      double step(double t) {
        const dt = 0.02;
        return ThrowPhysics.chargeForHold(t + dt, duration) -
            ThrowPhysics.chargeForHold(t, duration);
      }

      expect(ThrowPhysics.chargeForHold(0, duration), 0);
      expect(ThrowPhysics.chargeForHold(duration, duration), 1);
      expect(
        ThrowPhysics.chargeForHold(duration * 0.5, duration),
        greaterThan(0.5),
      );
      expect(step(0.05), greaterThan(step(0.65)));
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

    test('max power from the back line can reach every enemy cell', () {
      final size = Vector2(152, 152);
      final speed = ThrowPhysics.speedForCharge(1);
      for (var row = 0; row < ArenaGrid.rows; row++) {
        final from = ArenaGrid.throwOrigin(
          KidSide.player,
          ArenaGrid.cellCenter(KidSide.player, 0, row),
          size,
        );
        for (var column = 0; column < ArenaGrid.columnsPerSide; column++) {
          for (var targetRow = 0; targetRow < ArenaGrid.rows; targetRow++) {
            final to = ArenaGrid.hitCenter(
              ArenaGrid.cellCenter(KidSide.enemy, column, targetRow),
              size,
            );
            final velocity = ThrowPhysics.launchToward(
              from: from,
              to: to,
              speed: speed,
            );
            expect(
              velocity,
              isNotNull,
              reason: 'row $row -> $column,$targetRow',
            );
            final apex = from.y - ThrowPhysics.apexRise(velocity!);
            expect(apex, greaterThan(0));
          }
        }
      }
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

    test('kid move speed stays at or under projectile speed', () {
      final shot = ThrowPhysics.launchVelocity(
        charge: 1,
        aimDirection: Vector2(1, -0.45),
        speedScale: 1.35,
      );
      final pace = ThrowPhysics.kidMoveSpeed(speedScale: 1.35);
      expect(pace, lessThanOrEqualTo(shot.length + 0.001));
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
