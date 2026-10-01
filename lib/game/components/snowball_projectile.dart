import 'package:flame/components.dart';

import '../throw_physics.dart';
import 'kid_component.dart';

typedef SnowballHitCallback = void Function(
  SnowballProjectile ball,
  KidComponent target,
);

/// Gravity-arc snowball with circle hit vs kids.
class SnowballProjectile extends SpriteComponent {
  SnowballProjectile({
    required Sprite sprite,
    required Vector2 position,
    required this.velocity,
    required this.targets,
    required this.onHit,
    this.radius = 22,
    this.owner,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2.all(radius * 2.2),
         anchor: Anchor.center,
         priority: 20,
       );

  Vector2 velocity;
  final List<KidComponent> targets;
  final SnowballHitCallback onHit;
  final double radius;
  final KidComponent? owner;
  bool _spent = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;

    velocity.y += ThrowPhysics.gravity * dt;
    position += velocity * dt;

    for (final target in targets) {
      if (identical(target, owner) || target.isKo) continue;
      if (ThrowPhysics.circlesOverlap(
        position,
        radius,
        target.hitCenter,
        target.hitRadius,
      )) {
        _spent = true;
        onHit(this, target);
        removeFromParent();
        return;
      }
    }

    if (position.x < -80 ||
        position.x > 1360 ||
        position.y < -120 ||
        position.y > 820) {
      removeFromParent();
    }
  }
}
