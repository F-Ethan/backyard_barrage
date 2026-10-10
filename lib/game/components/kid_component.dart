import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../arena_grid.dart';
import '../combat_rules.dart';
import '../throw_physics.dart';
import 'damage_pop.dart';

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
    required this.turn30l,
    required this.turn15l,
    required this.turn15r,
    required this.turn30r,
    this.uprightKo = false,
    this.koDrop = 40,
    this.drawScale = 1,
    this.walkCycle,
  });

  Sprite idle;
  Sprite walk;
  Sprite charge;
  Sprite throwPose;
  Sprite hit;
  Sprite ko;
  Sprite pickup;
  Sprite turn30l;
  Sprite turn15l;
  Sprite turn15r;
  Sprite turn30r;

  /// No lying-down KO frame (the 3D pack). The upright pose tips over.
  bool uprightKo;

  /// How far the KO and knockdown frames sit below the feet. The 2D drafts
  /// need 40px; renders that lie on the feet line use 0.
  double koDrop;

  /// Art drawn this much larger than the body box, from the feet. Hit
  /// circles and depth do not change.
  double drawScale;

  /// Frames that loop while walking. Null or one frame uses [walk].
  List<Sprite>? walkCycle;
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
       turn30lSprite = poses.turn30l,
       turn15lSprite = poses.turn15l,
       turn15rSprite = poses.turn15r,
       turn30rSprite = poses.turn30r,
       _uprightKo = poses.uprightKo,
       _koDrop = poses.koDrop,
       _drawScale = poses.drawScale,
       _walkCycle = poses.walkCycle,
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
  Sprite turn30lSprite;
  Sprite turn15lSprite;
  Sprite turn15rSprite;
  Sprite turn30rSprite;
  bool _uprightKo;
  double _koDrop;
  double _drawScale;
  List<Sprite>? _walkCycle;
  double _walkClock = 0;
  int _walkFrame = 0;

  /// Seconds each run frame shows.
  static const double walkFrameSeconds = 0.13;

  /// Every frame this kid may show while walking.
  List<Sprite> get walkFrames {
    final cycle = _walkCycle;
    return cycle == null || cycle.isEmpty ? [walkSprite] : cycle;
  }

  /// Frost armor: a cold bubble around the kid while it lasts.
  bool armored = false;

  /// Freeze all: frozen in place, tinted icy, for this long.
  double _frozenTimer = 0;
  static final Paint _icePaint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0x8C9FE3FF),
      BlendMode.srcATop,
    );

  bool get isFrozen => _frozenTimer > 0;

  /// Freeze for [seconds]: no throwing or stepping (a stun) and an icy tint.
  void freeze(double seconds) {
    if (isKo) return;
    _frozenTimer = math.max(_frozenTimer, seconds);
    _stunTimer = math.max(_stunTimer, seconds);
    _chargingPose = false;
    _walking = false;
    _refreshSprite();
  }

  /// Shows a glint while winding up (long-range rivals).
  bool glint = false;

  /// Where the glint sits, from the feet, as a fraction of the art square
  /// (x forward-right, y up is negative). Null uses the throwing hand.
  Vector2? glintAt;
  double _glintAge = 0;

  /// A tint and pulsing glow in this color (rushers), or none.
  Color? get aura => _aura;
  set aura(Color? color) {
    _aura = color;
    _auraPaint = color == null
        ? null
        : (Paint()
            ..colorFilter = ColorFilter.mode(
              color.withValues(alpha: 0.32),
              BlendMode.srcATop,
            ));
  }

  Color? _aura;
  Paint? _auraPaint;
  double _auraAge = 0;

  /// Hearts when full. A player kid's can grow between waves (Health).
  int maxHp;
  int hp;

  /// Hits absorbed before HP or stun. Refilled at the start of each wave.
  int get shieldHits => _shieldHits;
  set shieldHits(int value) {
    _shieldHits = value < 0 ? 0 : value;
    // The most it has held since it was last empty, so a used shield
    // shows cracked.
    _shieldTop = _shieldHits == 0
        ? 0
        : (_shieldHits > _shieldTop ? _shieldHits : _shieldTop);
  }

  int _shieldHits = 0;
  int _shieldTop = 0;

  /// The shield has blocked a hit and still has some left.
  bool get shieldCracked => _shieldHits > 0 && _shieldHits < _shieldTop;

  /// Called when a block uses the shield's last hit (to drop the broken
  /// shield on the ground).
  void Function(KidComponent kid)? onShieldBroken;

  /// Spend one shield hit on a block. True when the shield took it.
  bool blockWithShield() {
    if (_shieldHits <= 0) return false;
    _shieldHits -= 1;
    if (_shieldHits == 0) {
      _shieldTop = 0;
      onShieldBroken?.call(this);
    }
    return true;
  }

  bool _selected = false;

  /// Hold the slumped pose this long, then fade. About 2.5s plus the fade.
  static const double koFadeDelay = 2.5;

  /// How long the fade from slumped to gone takes.
  static const double koFadeSeconds = 0.5;

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

  double _koAge = 0;

  /// Render-only feel. None of these move [position] or the hit circle.
  double _flashTimer = 0;
  double _recoilTimer = 0;
  double _recoilDir = 0;
  double _throwPoseTotal = 0.28;
  static const double flashSeconds = 0.09;
  static const double recoilSeconds = 0.2;
  static final Paint _flashPaint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0xD9FFFFFF),
      BlendMode.srcATop,
    );

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
  /// side-profile charge sprite. The other four are the mild turn yaws.
  ChargeYaw get chargeYaw => _chargeYaw;

  void applyPoses(KidPoseSprites poses) {
    idleSprite = poses.idle;
    walkSprite = poses.walk;
    chargeSprite = poses.charge;
    throwSprite = poses.throwPose;
    hitSprite = poses.hit;
    koSprite = poses.ko;
    pickupSprite = poses.pickup;
    turn30lSprite = poses.turn30l;
    turn15lSprite = poses.turn15l;
    turn15rSprite = poses.turn15r;
    turn30rSprite = poses.turn30r;
    _uprightKo = poses.uprightKo;
    _koDrop = poses.koDrop;
    _drawScale = poses.drawScale;
    _walkCycle = poses.walkCycle;
    _refreshSprite();
  }

  void showChargePose() {
    showChargeYaw(ChargeYaw.across);
  }

  /// Upright charge pose for this sweep angle.
  ///
  /// Player winter mirrors `30l`, `15l`, and the sheet charge so the kid
  /// faces +x toward the rivals. Enemy sprites are never mirrored.
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
    _throwPoseTotal = duration <= 0 ? 0.28 : duration;
    _refreshSprite();
  }

  /// A boss: each hit costs one HP with a short flinch, never a stun or a
  /// knockdown, so it keeps attacking.
  bool isBoss = false;

  /// Seconds a boss shows its hit pose.
  static const double bossFlinchSeconds = 0.25;

  /// A pose shown instead of the usual ones (a boss's special move). Null
  /// goes back to normal. The hit flash still draws over it.
  Sprite? get posedOverride => _posedOverride;
  set posedOverride(Sprite? next) {
    _posedOverride = next;
    _refreshSprite();
  }

  Sprite? _posedOverride;

  /// Draw-only height above the feet (a boss hop). Hits and depth ignore it.
  double lift = 0;

  void takeHit({double stunScale = 1}) {
    if (isKo) return;
    if (isBoss) {
      hp -= 1;
      if (hp <= 0) {
        hp = 0;
        _posedOverride = null;
        lift = 0;
        _applyKoLook();
        return;
      }
      _flash();
      _hitPoseTimer = bossFlinchSeconds;
      _refreshSprite();
      return;
    }
    if (blockWithShield()) {
      _flash();
      return;
    }
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
    if (result.knockedOut) {
      _stunTimer = 0;
      _downTimer = 0;
      _fragile = false;
      _hitPoseTimer = 0;
      _applyKoLook();
      return;
    }
    _flash();
    _fragile = result.fragile;
    final lock = result.lockSeconds * stunScale;
    _stunTimer = lock;
    _downDuration = lock <= 0 ? 1 : lock;
    _downTimer = result.knockdown ? lock : 0;
    _hitPoseTimer = result.knockdown ? 0 : lock;
    _refreshSprite();
  }

  /// A knock from a ball travelling along [direction] (+1 right, -1 left):
  /// the body jolts that way and squashes, then springs back.
  void recoil(double direction) {
    if (isKo) return;
    _recoilDir = direction.sign;
    _recoilTimer = recoilSeconds;
  }

  void _flash() {
    _flashTimer = flashSeconds;
    add(
      SequenceEffect([
        OpacityEffect.to(0.35, EffectController(duration: 0.08)),
        OpacityEffect.to(1.0, EffectController(duration: 0.12)),
      ]),
    );
  }

  void revive() {
    hp = maxHp;
    _frozenTimer = 0;
    armored = false;
    _chargingPose = false;
    _walking = false;
    _throwPoseTimer = 0;
    _hitPoseTimer = 0;
    _stunTimer = 0;
    _downTimer = 0;
    _fragile = false;
    shieldHits = 0;
    _selected = false;
    paint.colorFilter = null;
    for (final effect in children.whereType<Effect>().toList()) {
      effect.removeFromParent();
    }
    _koAge = 0;
    opacity = 1;
    _refreshSprite();
  }

  /// Out for this whole wave: knocked out in an earlier one and not
  /// brought back. Already faded and off the yard.
  /// Knocked out in one go (the Ice hound's bite), whatever HP is left.
  void knockOutNow() {
    if (isKo) return;
    hp = 0;
    shieldHits = 0;
    _stunTimer = 0;
    _downTimer = 0;
    _fragile = false;
    _frozenTimer = 0;
    armored = false;
    _applyKoLook();
  }

  void benchOut() {
    revive();
    hp = 0;
    _applyKoLook();
    _koAge = koFadeDelay + koFadeSeconds;
    opacity = 0;
  }

  void _applyKoLook() {
    _hitPoseTimer = 0;
    _chargingPose = false;
    _walking = false;
    _selected = false;
    _koAge = 0;
    paint.colorFilter = knockoutFilter;
    for (final effect in children.whereType<Effect>().toList()) {
      effect.removeFromParent();
    }
    opacity = 1;
    _refreshSprite();
  }

  void _refreshSprite() {
    if (isKo || _downTimer > 0) {
      sprite = koSprite;
      return;
    }
    final override = _posedOverride;
    if (override != null) {
      sprite = override;
      return;
    }
    if (_hitPoseTimer > 0) {
      sprite = hitSprite;
      return;
    }
    if (_chargingPose) {
      sprite = switch (_chargeYaw) {
        ChargeYaw.yaw30l => turn30lSprite,
        ChargeYaw.yaw15l => turn15lSprite,
        ChargeYaw.across => chargeSprite,
        ChargeYaw.yaw15r => turn15rSprite,
        ChargeYaw.yaw30r => turn30rSprite,
      };
      return;
    }
    if (_throwPoseTimer > 0) {
      sprite = throwSprite;
      return;
    }
    if (_walking) {
      final cycle = _walkCycle;
      sprite = cycle == null || cycle.isEmpty
          ? walkSprite
          : cycle[_walkFrame % cycle.length];
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
    _watchHealth(dt);
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
    if (_flashTimer > 0) _flashTimer -= dt;
    if (_frozenTimer > 0) _frozenTimer -= dt;
    final cycle = _walkCycle;
    if (_walking && cycle != null && cycle.length > 1) {
      _walkClock += dt;
      final frame = (_walkClock / walkFrameSeconds).floor() % cycle.length;
      if (frame != _walkFrame) {
        _walkFrame = frame;
        refresh = true;
      }
    } else {
      _walkClock = 0;
      _walkFrame = 0;
    }
    _glintAge = _chargingPose ? _glintAge + dt : 0;
    if (_aura != null) _auraAge += dt;
    if (_recoilTimer > 0) _recoilTimer -= dt;
    if (isKo) {
      _koAge += dt;
      final t = (_koAge - koFadeDelay) / koFadeSeconds;
      if (t <= 0) {
        opacity = 1;
      } else if (t >= 1) {
        opacity = 0;
      } else {
        opacity = 1 - t;
      }
    }
    if (refresh) _refreshSprite();
  }

  @override
  void render(Canvas canvas) {
    final fade = opacity.clamp(0.0, 1.0);
    if (fade <= 0) {
      super.render(canvas);
      return;
    }
    // Sprite paint already carries [opacity]. Custom marks (the X, the
    // ring) do not, so fade the whole body in one layer and draw the
    // sprite at full paint alpha inside it.
    if (fade < 0.999) {
      final saved = paint.color;
      paint.color = saved.withValues(alpha: 1);
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, fade),
      );
      _renderBody(canvas);
      canvas.restore();
      paint.color = saved;
      return;
    }
    _renderBody(canvas);
  }

  void _renderBody(Canvas canvas) {
    final scaled = _drawScale != 1;
    if (scaled) {
      final feet = Offset(size.x / 2, size.y);
      canvas.save();
      canvas.translate(feet.dx, feet.dy);
      canvas.scale(_drawScale);
      canvas.translate(-feet.dx, -feet.dy);
    }
    final lifted = lift > 0 && !isKo;
    if (lifted) {
      canvas.save();
      canvas.translate(0, -lift / ((scale.y == 0 ? 1 : scale.y) * _drawScale));
    }
    final moved = _applyFeelTransform(canvas);
    _renderPosed(canvas);
    if (moved) canvas.restore();
    if (lifted) canvas.restore();
    if (scaled) canvas.restore();
    if (glint && _chargingPose && !isKo && !isStunned) _drawGlint(canvas);
    if (armored && !isKo) _drawArmor(canvas);
    if (!isKo && !isBoss) _drawHealthBar(canvas);
  }

  /// Frost armor art (an ice bubble). Shared by every kid; set once the
  /// image loads. Null draws the plain ring.
  static Sprite? armorSprite;

  /// The iron shield held while [shieldHits] is above 0. Shared by every
  /// kid; set once the image loads.
  static Sprite? shieldSprite;

  /// The same shield after it has blocked a hit.
  static Sprite? shieldCrackedSprite;

  /// Drawn size of the art about the feet (rivals and bosses vary).
  double get drawScale => _drawScale;

  /// Where the iron shield sits on this kid's standing art, as fractions
  /// of the 512² render (centre x, centre y, side), and whether it is
  /// flipped. Null for art with no mapped hand (the shield badge still
  /// shows the count).
  ({double x, double y, double side, bool mirror})? shieldSpot;

  /// Standing frames only: the hand positions are mapped on the idle art.
  bool get _standing =>
      identical(sprite, idleSprite) || identical(sprite, pickupSprite);

  /// The iron shield in the kid's front hand, in the render's own space
  /// (the 512² art is drawn from a 471px square starting 20.5px in).
  void _drawHeldShield(Canvas canvas) {
    final art = shieldCracked
        ? (shieldCrackedSprite ?? shieldSprite)
        : shieldSprite;
    final spot = shieldSpot;
    if (art == null || spot == null || shieldHits <= 0 || !_standing) return;
    const crop = 471.0;
    const left = 20.5;
    final cx = (spot.x * 512 - left) / crop * size.x;
    final cy = spot.y * 512 / crop * size.y;
    final side = spot.side * 512 / crop * size.x;
    canvas.save();
    canvas.translate(cx, cy);
    if (spot.mirror) canvas.scale(-1, 1);
    art.render(
      canvas,
      position: Vector2(-side / 2, -side / 2),
      size: Vector2.all(side),
    );
    canvas.restore();
  }

  /// Seconds the overhead health bar stays up after a hit.
  static const double healthBarSeconds = 1.5;

  double _barTimer = 0;
  double _barClock = 0;
  int? _seenHp;
  int? _seenShield;

  /// The overhead bar is showing (a recent hit, or one hit from down).
  bool get healthBarVisible => !isKo && !isBoss && (_barTimer > 0 || onLastHit);

  /// One more hit puts this kid down (and it could take more than one).
  bool get onLastHit => !isKo && hp == 1 && maxHp > 1 && shieldHits == 0;

  /// Take the current hearts and shield as the baseline, so setting them
  /// between waves does not pop a "-1".
  void syncHealthSeen() {
    _seenHp = hp;
    _seenShield = shieldHits;
    _barTimer = 0;
  }

  /// Notices hearts or shield going down (from any hit, blast, or bite):
  /// shows the bar and pops the damage.
  void _watchHealth(double dt) {
    _barClock += dt;
    if (_barTimer > 0) _barTimer -= dt;
    final seenHp = _seenHp ?? hp;
    final seenShield = _seenShield ?? shieldHits;
    final lost = seenHp - hp;
    final blocked = seenShield - shieldHits;
    if (lost > 0 || (blocked > 0 && !isKo)) {
      _barTimer = healthBarSeconds;
      final at = hitCenter - Vector2(0, size.y * scale.y * 0.55);
      parent?.add(
        lost > 0
            ? DamagePop(text: '-$lost', position: at)
            : DamagePop(
                text: 'Blocked',
                position: at,
                color: const Color(0xFFBFD4FF),
              ),
      );
    }
    _seenHp = hp;
    _seenShield = shieldHits;
  }

  /// A small bar over the head: one pip per heart, red and pulsing on the
  /// last one, with a shield and the hits it still blocks at its left.
  void _drawHealthBar(Canvas canvas) {
    if (!healthBarVisible) return;
    // Top of the hat: the art stands about 85% of its box, scaled about
    // the feet.
    final headTop = size.y * (1 - 0.851 * _drawScale);
    const height = 10.0;
    final width = size.x * 0.56;
    final top = headTop - height - 8;
    final left = size.x / 2 - width / 2;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(left - 2, top - 2, width + 4, height + 4),
      const Radius.circular(7),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xCC1A2332));
    final fraction = maxHp <= 0 ? 0.0 : hp / maxHp;
    final last = onLastHit;
    final pulse = last
        ? 0.55 + 0.45 * (0.5 + 0.5 * math.sin(_barClock * 9))
        : 1.0;
    final fill = last
        ? const Color(0xFFFF4D4D)
        : (fraction > 0.5 ? const Color(0xFF2ECC71) : const Color(0xFFF1C40F));
    final pips = maxHp.clamp(1, 10);
    const gap = 2.0;
    final pip = (width - gap * (pips - 1)) / pips;
    final filled = maxHp <= 10 ? hp : (fraction * pips).ceil();
    for (var i = 0; i < pips; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * (pip + gap), top, pip, height),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = i < filled
              ? fill.withValues(alpha: pulse)
              : const Color(0x33FFFFFF),
      );
    }
    if (last) {
      canvas.drawRRect(
        frame,
        Paint()
          ..color = const Color(0xFFFF4D4D).withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (shieldHits > 0) {
      _drawBarShield(canvas, Offset(left - 14, top + height / 2));
    }
  }

  /// A small shield with its count, at the bar's left end.
  void _drawBarShield(Canvas canvas, Offset center) {
    final shield = Path()
      ..moveTo(center.dx, center.dy - 11)
      ..lineTo(center.dx + 10, center.dy - 7)
      ..quadraticBezierTo(
        center.dx + 9,
        center.dy + 6,
        center.dx,
        center.dy + 12,
      )
      ..quadraticBezierTo(
        center.dx - 9,
        center.dy + 6,
        center.dx - 10,
        center.dy - 7,
      )
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(shield, Paint()..color = const Color(0xFF3D7CFF));
    final text = TextPainter(
      text: TextSpan(
        text: '$shieldHits',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(center.dx - text.width / 2, center.dy - text.height / 2),
    );
  }

  void _drawArmor(Canvas canvas) {
    final center = Offset(size.x / 2, size.y * 0.55);
    final r = size.x * 0.5;
    final bubble = armorSprite;
    if (bubble != null) {
      final side = r * 2.3;
      bubble.render(
        canvas,
        position: Vector2(center.dx - side / 2, center.dy - side / 2),
        size: Vector2.all(side),
        overridePaint: Paint()..color = const Color(0xD9FFFFFF),
      );
      return;
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0x339FE3FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xB3DFF6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// A pulsing four-point sparkle on the ball.
  void _drawGlint(Canvas canvas) {
    final at = glintAt;
    final hand = at == null
        ? throwOrigin - position + Vector2(size.x / 2, size.y)
        : Vector2(size.x / 2, size.y) +
              Vector2(at.x * size.x, at.y * size.y) * _drawScale;
    final pulse = 0.6 + 0.4 * math.sin(_glintAge * 14);
    final r = 14.0 * pulse;
    final center = Offset(hand.x, hand.y);
    canvas.drawCircle(
      center,
      r * 0.9,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final ray = Paint()
      ..color = const Color(0xFFFFF8D6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-r, 0), center.translate(r, 0), ray);
    canvas.drawLine(center.translate(0, -r), center.translate(0, r), ray);
  }

  /// Jolt, squash, and throw lunge, pivoting at the feet. Returns true when
  /// it saved the canvas.
  bool _applyFeelTransform(Canvas canvas) {
    if (isKo) return false;
    final recoil = _recoilTimer > 0 ? _recoilTimer / recoilSeconds : 0.0;
    final lunge = _throwPoseTimer > 0
        ? math.sin(math.pi * (1 - _throwPoseTimer / _throwPoseTotal))
        : 0.0;
    if (recoil <= 0 && lunge <= 0) return false;
    final forward = side == KidSide.player ? 1.0 : -1.0;
    final feet = Offset(size.x / 2, size.y);
    canvas.save();
    canvas.translate(feet.dx + _recoilDir * 12 * recoil, feet.dy);
    if (recoil > 0) {
      final squash = 0.14 * recoil;
      canvas.scale(1 + squash, 1 - squash);
    }
    if (lunge > 0) canvas.rotate(forward * 0.16 * lunge);
    canvas.translate(-feet.dx, -feet.dy);
    return true;
  }

  void _renderPosed(Canvas canvas) {
    if (selected && !isKo) {
      final glow = Paint()
        ..color = const Color(0x663D7CFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(size.x / 2, size.y * 0.58), size.x * 0.46, glow);
    }
    final aura = _aura;
    if (aura != null && !isKo) {
      final pulse = 0.75 + 0.25 * math.sin(_auraAge * 5);
      canvas.drawCircle(
        Offset(size.x / 2, size.y * 0.58),
        size.x * 0.42,
        Paint()
          ..color = aura.withValues(alpha: 0.45 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    if (isKo && _uprightKo) {
      _renderTippedOver(canvas);
      return;
    }
    canvas.save();
    if (isKo) {
      canvas.translate(0, _koDrop);
    } else if (_downTimer > 0 && _downDuration > 0) {
      final t = (_downTimer / _downDuration).clamp(0.0, 1.0);
      final sink = _koDrop * 0.75;
      final down = t > 0.35 ? sink : sink * (t / 0.35);
      canvas.translate(0, down);
    }
    super.render(canvas);
    final auraPaint = _auraPaint;
    if (auraPaint != null && !isKo) {
      sprite?.render(canvas, size: size, overridePaint: auraPaint);
    }
    if (_flashTimer > 0 && !isKo) {
      sprite?.render(canvas, size: size, overridePaint: _flashPaint);
    }
    if (_frozenTimer > 0 && !isKo) {
      sprite?.render(canvas, size: size, overridePaint: _icePaint);
    }
    if (!isKo) _drawHeldShield(canvas);
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

  /// Upright art laid on its back, pivoting on the boots, so a KO reads
  /// without a separate lying-down frame.
  void _renderTippedOver(Canvas canvas) {
    final lean = side == KidSide.player ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.rotate(lean * 1.35);
    canvas.translate(-size.x / 2, -size.y);
    super.render(canvas);
    canvas.restore();
    _drawKnockoutMark(
      canvas,
      center: Offset(size.x / 2 + lean * size.y * 0.55, size.y * 0.72),
    );
  }

  void _drawKnockoutMark(Canvas canvas, {Offset? center}) {
    final upright = center == null;
    center ??= Offset(size.x / 2, size.y * 0.32);
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
    if (upright) _drawSwirl(canvas, Offset(size.x / 2, size.y * 0.08));
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
