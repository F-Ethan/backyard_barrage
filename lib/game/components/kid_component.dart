import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

enum KidSide { player, enemy }

/// Simple kid sprite: idle / throw poses, HP, KO tint.
class KidComponent extends SpriteComponent {
  KidComponent({
    required this.side,
    required this.idleSprite,
    required this.throwSprite,
    required Vector2 position,
    required Vector2 size,
    this.maxHp = 2,
  }) : hp = maxHp,
       super(
         sprite: idleSprite,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
         priority: 10,
       );

  final KidSide side;
  final Sprite idleSprite;
  final Sprite throwSprite;
  final int maxHp;
  int hp;
  bool get isKo => hp <= 0;

  double _throwPoseTimer = 0;

  void showThrowPose({double duration = 0.28}) {
    if (isKo) return;
    sprite = throwSprite;
    _throwPoseTimer = duration;
  }

  void takeHit() {
    if (isKo) return;
    hp = (hp - 1).clamp(0, maxHp);
    add(
      SequenceEffect([
        OpacityEffect.to(0.35, EffectController(duration: 0.08)),
        OpacityEffect.to(1.0, EffectController(duration: 0.12)),
      ]),
    );
    if (isKo) {
      _applyKoLook();
    }
  }

  void _applyKoLook() {
    sprite = idleSprite;
    paint.colorFilter = const ColorFilter.mode(
      Color(0xAA2C3E50),
      BlendMode.srcATop,
    );
    add(
      OpacityEffect.to(
        0.55,
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
  }

  Vector2 get throwOrigin {
    final facingRight = side == KidSide.player;
    return position +
        Vector2(facingRight ? size.x * 0.22 : -size.x * 0.22, -size.y * 0.55);
  }

  Vector2 get hitCenter => position + Vector2(0, -size.y * 0.45);

  double get hitRadius => size.x * 0.28;

  @override
  void update(double dt) {
    super.update(dt);
    if (_throwPoseTimer > 0) {
      _throwPoseTimer -= dt;
      if (_throwPoseTimer <= 0 && !isKo) {
        sprite = idleSprite;
      }
    }
  }
}
