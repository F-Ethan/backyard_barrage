import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../arena_grid.dart';
import '../combat_rules.dart';
import '../throw_physics.dart';

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
    required this.pickup,
    required this.turnBack,
    required this.turnQuarter,
    required this.turnFront,
  });

  Sprite idle;
  Sprite walk;
  Sprite charge;
  Sprite throwPose;
  Sprite hit;
  Sprite ko;
  Sprite pickup;
  Sprite turnBack;
  Sprite turnQuarter;
  Sprite turnFront;
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
       pickupSprite = poses.pickup,
       turnBackSprite = poses.turnBack,
       turnQuarterSprite = poses.turnQuarter,
       turnFrontSprite = poses.turnFront,
       super(
         sprite: poses.idle,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
       ) {
    syncDepth();
  }

  final KidSide side;
  Sprite idleSprite;
  Sprite walkSprite;
  Sprite chargeSprite;
  Sprite throwSprite;
  Sprite hitSprite;
  Sprite koSprite;
  Sprite pickupSprite;
  Sprite turnBackSprite;
  Sprite turnQuarterSprite;
  Sprite turnFrontSprite;
  final int maxHp;
  int hp;
  bool _selected = false;

  /// Grey, dim, and marked so a downed kid does not read as still in the fight.
  static const ColorFilter knockoutFilter = ColorFilter.matrix(<double>[
    0.30,
    0.45,
    0.10,
    0,
    12,
    0.30,
    0.45,
    0.10,
    0,
    12,
    0.30,
    0.45,
    0.10,
    0,
    12,
    0,
    0,
    0,
    0.62,
    0,
  ]);

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    _refreshSprite();
  }

  bool get isKo => hp <= 0;

  /// Cannot move or throw. Brush-off, knockdown, and the ally stun all count.
  bool get isStunned => _stunTimer > 0;

  bool get isFlinching => isStunned;

  /// Set on an ally's first hit. Cleared when the stun ends. A hit while
  /// this is set knocks them out.
  bool get isFragile => _fragile;

  /// Enemy second hit: the KO pose, then they stand back up.
  bool get isDown => _downTimer > 0;

  double get stunRemaining => _stunTimer;

  double _throwPoseTimer = 0;
  double _hitPoseTimer = 0;
  double _stunTimer = 0;
  double _downTimer = 0;
  double _downDuration = 1;
  bool _fragile = false;
  bool _chargingPose = false;
  bool _walking = false;
  ChargeYaw _chargeYaw = ChargeYaw.across;

  /// Yaw shown while this kid is in the charge pose. Across is the
  /// side-profile charge sprite. The other three are the Studio turn poses.
  ChargeYaw get chargeYaw => _chargeYaw;

  void applyPoses(KidPoseSprites poses) {
    idleSprite = poses.idle;
    walkSprite = poses.walk;
    chargeSprite = poses.charge;
    throwSprite = poses.throwPose;
    hitSprite = poses.hit;
    koSprite = poses.ko;
    pickupSprite = poses.pickup;
    turnBackSprite = poses.turnBack;
    turnQuarterSprite = poses.turnQuarter;
    turnFrontSprite = poses.turnFront;
    _refreshSprite();
  }

  void showChargePose() {
    showChargeYaw(ChargeYaw.across);
  }

  /// Upright charge pose for this sweep angle. Sprites are not mirrored.
  void showChargeYaw(ChargeYaw yaw) {
    if (isKo) return;
    _chargingPose = true;
    _walking = false;
    _throwPoseTimer = 0;
    _chargeYaw = yaw;
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
    final result = CombatRules.resolveHit(
      ally: side == KidSide.player,
      hp: hp,
      maxHp: maxHp,
      stunned: isStunned,
      fragile: _fragile,
    );
    hp = result.hp;
    _chargingPose = false;
    _walking = false;
    _throwPoseTimer = 0;
    add(
      SequenceEffect([
        OpacityEffect.to(0.35, EffectController(duration: 0.08)),
        OpacityEffect.to(1.0, EffectController(duration: 0.12)),
      ]),
    );
    if (result.knockedOut) {
      _stunTimer = 0;
      _downTimer = 0;
      _fragile = false;
      _hitPoseTimer = 0;
      _applyKoLook();
      return;
    }
    _fragile = result.fragile;
    _stunTimer = result.lockSeconds;
    _downDuration = result.lockSeconds <= 0 ? 1 : result.lockSeconds;
    _downTimer = result.knockdown ? result.lockSeconds : 0;
    _hitPoseTimer = result.knockdown ? 0 : result.lockSeconds;
    _refreshSprite();
  }

  void revive() {
    hp = maxHp;
    _chargingPose = false;
    _walking = false;
    _throwPoseTimer = 0;
    _hitPoseTimer = 0;
    _stunTimer = 0;
    _downTimer = 0;
    _fragile = false;
    _selected = false;
    paint.colorFilter = null;
    for (final effect in children.whereType<Effect>().toList()) {
      effect.removeFromParent();
    }
    opacity = 1;
    _refreshSprite();
  }

  void _applyKoLook() {
    _hitPoseTimer = 0;
    _chargingPose = false;
    _walking = false;
    _selected = false;
    paint.colorFilter = knockoutFilter;
    opacity = 1;
    _refreshSprite();
  }

  void _refreshSprite() {
    if (isKo || _downTimer > 0) {
      sprite = koSprite;
      return;
    }
    if (_hitPoseTimer > 0) {
      sprite = hitSprite;
      return;
    }
    if (_chargingPose) {
      sprite = switch (_chargeYaw) {
        ChargeYaw.back => turnBackSprite,
        ChargeYaw.across => chargeSprite,
        ChargeYaw.quarter => turnQuarterSprite,
        ChargeYaw.front => turnFrontSprite,
      };
      return;
    }
    if (_throwPoseTimer > 0) {
      sprite = throwSprite;
      return;
    }
    if (_walking) {
      sprite = walkSprite;
      return;
    }
    sprite = _selected ? pickupSprite : idleSprite;
  }

  Vector2 get throwOrigin {
    final facingRight = side == KidSide.player;
    return position +
        Vector2(facingRight ? size.x * 0.22 : -size.x * 0.22, -size.y * 0.55);
  }

  Vector2 get hitCenter => position + Vector2(0, -size.y * 0.45);

  /// Small body circle. A snowball can pass the sprite and still miss.
  /// Uses [size], not the drawn depth scale, so a far kid is not a smaller target.
  double get hitRadius => size.x * ThrowPhysics.kidHitScale;

  /// Feet stay put: the sprite is anchored at the bottom center, and the
  /// same factor scales X and Y. Hit circles ignore this.
  void syncDepth() {
    priority = ArenaGrid.depthOrder(hitCenter.y);
    final factor = ArenaGrid.depthScale(position.y, groundTrack: false);
    scale.setValues(factor, factor);
  }

  @override
  void update(double dt) {
    super.update(dt);
    syncDepth();
    var refresh = false;
    if (_stunTimer > 0) {
      _stunTimer -= dt;
      if (_stunTimer <= 0) {
        _stunTimer = 0;
        _fragile = false;
        refresh = true;
      }
    }
    if (_downTimer > 0) {
      _downTimer -= dt;
      if (_downTimer <= 0) {
        _downTimer = 0;
        refresh = true;
      }
    }
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
    if (selected && !isKo) {
      final glow = Paint()
        ..color = const Color(0x663D7CFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(size.x / 2, size.y * 0.58), size.x * 0.46, glow);
    }
    canvas.save();
    if (isKo) {
      canvas.translate(0, 40);
    } else if (_downTimer > 0 && _downDuration > 0) {
      final t = (_downTimer / _downDuration).clamp(0.0, 1.0);
      final down = t > 0.35 ? 30.0 : 30.0 * (t / 0.35);
      canvas.translate(0, down);
    }
    super.render(canvas);
    if (isKo) {
      _drawKnockoutMark(canvas);
      canvas.restore();
      return;
    }
    canvas.restore();
    if (isStunned && _downTimer <= 0) _drawDizzy(canvas);
    if (!selected) return;
    final oval = Rect.fromCenter(
      center: Offset(size.x / 2, size.y - 8),
      width: size.x * 0.62,
      height: 18,
    );
    canvas.drawOval(oval, Paint()..color = const Color(0x883D7CFF));
    canvas.drawOval(
      oval,
      Paint()
        ..color = const Color(0xFFFFE66D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawKnockoutMark(Canvas canvas) {
    final center = Offset(size.x / 2, size.y * 0.32);
    canvas.drawCircle(center, 30, Paint()..color = const Color(0xF2FFF8F0));
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..color = const Color(0xFF2C3E50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final mark = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    const arm = 16.0;
    canvas.drawLine(
      center.translate(-arm, -arm),
      center.translate(arm, arm),
      mark,
    );
    canvas.drawLine(
      center.translate(arm, -arm),
      center.translate(-arm, arm),
      mark,
    );
    _drawSwirl(canvas, Offset(size.x / 2, size.y * 0.08));
  }

  void _drawDizzy(Canvas canvas) {
    _drawSwirl(canvas, Offset(size.x / 2, size.y * 0.12));
    final star = Paint()
      ..color = const Color(0xFFFFE66D)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final spot in [
      Offset(size.x / 2 - 18, size.y * 0.08),
      Offset(size.x / 2 + 20, size.y * 0.1),
    ]) {
      canvas.drawLine(spot.translate(-6, 0), spot.translate(6, 0), star);
      canvas.drawLine(spot.translate(0, -6), spot.translate(0, 6), star);
    }
  }

  void _drawSwirl(Canvas canvas, Offset origin) {
    final paint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: origin, width: 40, height: 18),
      0.3,
      2.4,
      false,
      paint,
    );
  }
}
