import 'package:flame/components.dart';

import '../combat_rules.dart';
import '../throw_physics.dart';
import 'fort_component.dart';
import 'kid_component.dart';

typedef ProjectileHit = void Function(LobProjectile shot, KidComponent target);
typedef FortBlocked = void Function(LobProjectile shot);

/// Gravity-arc snowball or water balloon.
class LobProjectile extends SpriteComponent {
  LobProjectile({
    required Sprite sprite,
    required Vector2 position,
    required this.velocity,
    required this.targets,
    required this.onHit,
    this.fort,
    this.onFortHit,
    this.blockedByFort = false,
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
  final ProjectileHit onHit;
  final FortComponent? fort;
  final FortBlocked? onFortHit;
  final bool blockedByFort;
  final double radius;
  final KidComponent? owner;
  bool _spent = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;

    velocity.y += ThrowPhysics.gravity * dt;
    position += velocity * dt;

    final cover = fort;
    if (blockedByFort &&
        cover != null &&
        CombatRules.fortAbsorbsShot(
          fortHp: cover.hp,
          fromEnemy: true,
          fortRect: cover.hitRect,
          center: position,
          radius: radius,
        )) {
      _spent = true;
      onFortHit?.call(this);
      removeFromParent();
      return;
    }

    for (final target in List<KidComponent>.of(targets)) {
      if (identical(target, owner) || target.isKo) continue;
      if (!ThrowPhysics.circlesOverlap(
        position,
        radius,
        target.hitCenter,
        target.hitRadius,
      )) {
        continue;
      }
      final shelter = fort;
      if (blockedByFort && shelter != null && shelter.shelters(target)) {
        _spent = true;
        onFortHit?.call(this);
        removeFromParent();
        return;
      }
      _spent = true;
      onHit(this, target);
      removeFromParent();
      return;
    }

    if (position.x < -80 ||
        position.x > 1360 ||
        position.y < -120 ||
        position.y > 820) {
      removeFromParent();
    }
  }
}
