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
        ThrowPhysics.circlesOverlap(
          Vector2(0, 0),
          10,
          Vector2(15, 0),
          10,
        ),
        isTrue,
      );
      expect(
        ThrowPhysics.circlesOverlap(
          Vector2(0, 0),
          10,
          Vector2(50, 0),
          10,
        ),
        isFalse,
      );
    });

    test('defaultAim biases upward toward target', () {
      final aim = ThrowPhysics.defaultAim(Vector2(0, 0), Vector2(200, 0));
      expect(aim.x, greaterThan(0));
      expect(aim.y, lessThan(0));
    });
  });
}
