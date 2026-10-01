import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

enum KidSide { player, enemy }

/// Kid sprite with idle / charge / throw / hit / KO poses.
class KidComponent extends SpriteComponent {
  KidComponent({
    required this.side,
    required this.idleSprite,
    required this.throwSprite,
    required Vector2 position,
    required Vector2 size,
    this.chargeSprite,
    this.hitSprite,
    this.koSprite,
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
  final Sprite? chargeSprite;
  final Sprite? hitSprite;
  final Sprite? koSprite;
  final int maxHp;
  int hp;
  bool get isKo => hp <= 0;

  double _throwPoseTimer = 0;
  double _hitPoseTimer = 0;
  bool _chargingPose = false;

  void showChargePose() {
    if (isKo) return;
    _chargingPose = true;
    _throwPoseTimer = 0;
    _hitPoseTimer = 0;
    sprite = chargeSprite ?? idleSprite;
  }

  void clearChargePose() {
    if (!_chargingPose) return;
    _chargingPose = false;
    if (!isKo && _throwPoseTimer <= 0 && _hitPoseTimer <= 0) {
      sprite = idleSprite;
    }
  }

  void showThrowPose({double duration = 0.28}) {
    if (isKo) return;
    _chargingPose = false;
    _hitPoseTimer = 0;
    sprite = throwSprite;
    _throwPoseTimer = duration;
  }

  void takeHit() {
    if (isKo) return;
    hp = (hp - 1).clamp(0, maxHp);
    _chargingPose = false;
    _throwPoseTimer = 0;
    add(
      SequenceEffect([
        OpacityEffect.to(0.35, EffectController(duration: 0.08)),
        OpacityEffect.to(1.0, EffectController(duration: 0.12)),
      ]),
    );
    if (isKo) {
      _applyKoLook();
      return;
    }
    final hit = hitSprite;
    if (hit != null) {
      sprite = hit;
      _hitPoseTimer = 0.35;
    }
  }

  void _applyKoLook() {
    sprite = koSprite ?? idleSprite;
    // Mild fade; prefer KO art over heavy tint when available.
    if (koSprite == null) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0xAA2C3E50),
        BlendMode.srcATop,
      );
    }
    add(
      OpacityEffect.to(
        0.7,
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
    if (_hitPoseTimer > 0) {
      _hitPoseTimer -= dt;
      if (_hitPoseTimer <= 0 && !isKo && !_chargingPose) {
        sprite = idleSprite;
      }
    }
    if (_throwPoseTimer > 0) {
      _throwPoseTimer -= dt;
      if (_throwPoseTimer <= 0 && !isKo && !_chargingPose && _hitPoseTimer <= 0) {
        sprite = idleSprite;
      }
    }
  }
}
