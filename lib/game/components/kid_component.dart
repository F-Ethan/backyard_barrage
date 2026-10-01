import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

enum KidSide { player, enemy }

/// One season's pose sheet for a kid.
class KidPoseSprites {
  KidPoseSprites({
    required this.idle,
    required this.walk,
    required this.charge,
    required this.throwPose,
    required this.hit,
    required this.ko,
  });

  Sprite idle;
  Sprite walk;
  Sprite charge;
  Sprite throwPose;
  Sprite hit;
  Sprite ko;
}

/// Kid sprite with idle / walk / charge / throw / hit / KO poses.
class KidComponent extends SpriteComponent {
  KidComponent({
    required this.side,
    required KidPoseSprites poses,
    required Vector2 position,
    required Vector2 size,
    this.maxHp = 2,
  }) : hp = maxHp,
       idleSprite = poses.idle,
       walkSprite = poses.walk,
       chargeSprite = poses.charge,
       throwSprite = poses.throwPose,
       hitSprite = poses.hit,
       koSprite = poses.ko,
       super(
         sprite: poses.idle,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
         priority: side == KidSide.player ? 11 : 10,
       );

  final KidSide side;
  Sprite idleSprite;
  Sprite walkSprite;
  Sprite chargeSprite;
  Sprite throwSprite;
  Sprite hitSprite;
  Sprite koSprite;
  final int maxHp;
  int hp;
  bool selected = false;

  bool get isKo => hp <= 0;
  bool get isFlinching => _hitPoseTimer > 0;

  double _throwPoseTimer = 0;
  double _hitPoseTimer = 0;
  bool _chargingPose = false;
  bool _walking = false;

  void applyPoses(KidPoseSprites poses) {
    idleSprite = poses.idle;
    walkSprite = poses.walk;
    chargeSprite = poses.charge;
    throwSprite = poses.throwPose;
    hitSprite = poses.hit;
    koSprite = poses.ko;
    _refreshSprite();
  }

  void showChargePose() {
    if (isKo) return;
    _chargingPose = true;
    _walking = false;
    _throwPoseTimer = 0;
    _refreshSprite();
  }

  void clearChargePose() {
    if (!_chargingPose) return;
    _chargingPose = false;
    _refreshSprite();
  }

  void setWalking(bool walking) {
    if (isKo) return;
    _walking = walking;
    if (walking) _chargingPose = false;
    _refreshSprite();
  }

  void showThrowPose({double duration = 0.28}) {
    if (isKo) return;
    _chargingPose = false;
    _walking = false;
    _hitPoseTimer = 0;
    _throwPoseTimer = duration;
    _refreshSprite();
  }

  void takeHit() {
    if (isKo) return;
    hp = (hp - 1).clamp(0, maxHp);
    _chargingPose = false;
    _walking = false;
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
    _hitPoseTimer = 0.35;
    _refreshSprite();
  }

  void revive() {
    hp = maxHp;
    _chargingPose = false;
    _walking = false;
    _throwPoseTimer = 0;
    _hitPoseTimer = 0;
    selected = false;
    paint.colorFilter = null;
    for (final effect in children.whereType<Effect>().toList()) {
      effect.removeFromParent();
    }
    opacity = 1;
    _refreshSprite();
  }

  void _applyKoLook() {
    _hitPoseTimer = 0;
    _refreshSprite();
    add(
      OpacityEffect.to(
        0.7,
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
  }

  void _refreshSprite() {
    if (isKo) {
      sprite = koSprite;
      return;
    }
    if (_hitPoseTimer > 0) {
      sprite = hitSprite;
      return;
    }
    if (_chargingPose) {
      sprite = chargeSprite;
      return;
    }
    if (_throwPoseTimer > 0) {
      sprite = throwSprite;
      return;
    }
    sprite = _walking ? walkSprite : idleSprite;
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
    var refresh = false;
    if (_hitPoseTimer > 0) {
      _hitPoseTimer -= dt;
      if (_hitPoseTimer <= 0) refresh = true;
    }
    if (_throwPoseTimer > 0) {
      _throwPoseTimer -= dt;
      if (_throwPoseTimer <= 0) refresh = true;
    }
    if (refresh) _refreshSprite();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!selected || isKo) return;
    final ring = Paint()
      ..color = const Color(0xCCFFE66D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 8),
        width: size.x * 0.5,
        height: 14,
      ),
      ring,
    );
  }
}
