import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'components/charge_indicator.dart';
import 'components/hud_hearts.dart';
import 'components/impact_burst.dart';
import 'components/kid_component.dart';
import 'components/overlay_banner.dart';
import 'components/snowball_projectile.dart';
import 'throw_physics.dart';

/// Winter arena MVP: charge → aim → lob snowball, 2-hit KO, wave-clear stub.
class BackyardBarrageGame extends FlameGame {
  BackyardBarrageGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: worldWidth,
            height: worldHeight,
          ),
        );

  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double chargeSeconds = 0.85;

  late final KidComponent player;
  late final KidComponent enemy;
  late final ChargeIndicator chargeHud;
  late Sprite snowballSprite;
  late Sprite impactSprite;

  bool _charging = false;
  double _charge = 0;
  Vector2 _aimDir = Vector2(1, -0.55);
  Vector2? _dragStart;
  bool _waveCleared = false;
  OverlayBanner? _banner;

  @override
  Color backgroundColor() => const Color(0xFFA8D4F0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final bg = await loadSprite('world/backyard_bg_winter_draft.png');
    final playerIdle =
        await loadSprite('characters/player/player_idle_winter_draft.png');
    final playerThrow =
        await loadSprite('characters/player/player_throw_winter_draft.png');
    final enemyIdle =
        await loadSprite('characters/enemy/enemy_idle_winter_draft.png');
    // Reuse idle as throw fallback if needed; throw asset exists for enemy too.
    final enemyThrow =
        await loadSprite('characters/enemy/enemy_throw_winter_draft.png');
    snowballSprite = await loadSprite('projectiles/snowball_draft.png');
    impactSprite = await loadSprite('vfx/impact_snow_draft.png');
    final glow = await loadSprite('vfx/charge_glow_draft.png');
    Sprite? heart;
    try {
      heart = await loadSprite('ui/heart_draft.png');
    } catch (_) {
      heart = null;
    }

    world.add(
      SpriteComponent(
        sprite: bg,
        size: Vector2(worldWidth, worldHeight),
        position: Vector2.zero(),
        priority: 0,
      ),
    );

    const kidSize = 168.0;
    player = KidComponent(
      side: KidSide.player,
      idleSprite: playerIdle,
      throwSprite: playerThrow,
      position: Vector2(240, 560),
      size: Vector2.all(kidSize),
      maxHp: 2,
    );
    enemy = KidComponent(
      side: KidSide.enemy,
      idleSprite: enemyIdle,
      throwSprite: enemyThrow,
      position: Vector2(1040, 560),
      size: Vector2.all(kidSize),
      maxHp: 2,
    );
    world.add(player);
    world.add(enemy);

    chargeHud = ChargeIndicator(glowSprite: glow);
    world.add(chargeHud);
    world.add(HudHearts(target: enemy, heartSprite: heart));

    // Full-arena drag catcher for charge/aim/release.
    world.add(
      _ArenaInput(
        size: Vector2(worldWidth, worldHeight),
        onChargeStart: _onChargeStart,
        onChargeUpdate: _onChargeUpdate,
        onChargeEnd: _onChargeEnd,
      ),
    );

    // Hint banner
    world.add(
      TextComponent(
        text: 'Hold & drag to charge/aim · release to throw',
        position: Vector2(worldWidth / 2, 24),
        anchor: Anchor.topCenter,
        priority: 80,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xEEFFF8F0),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0xAA2C3E50), blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  void _onChargeStart(Vector2 worldPos) {
    if (_waveCleared || player.isKo) return;
    _charging = true;
    _charge = 0.12;
    _dragStart = worldPos.clone();
    _aimDir = ThrowPhysics.defaultAim(player.throwOrigin, enemy.hitCenter);
    chargeHud.visibleCharge = true;
    chargeHud.charge = _charge;
    chargeHud.aimDir = _aimDir;
    chargeHud.anchorWorld = player.throwOrigin;
  }

  void _onChargeUpdate(Vector2 worldPos) {
    if (!_charging) return;
    final start = _dragStart;
    if (start != null) {
      final delta = worldPos - start;
      // Prefer aim relative to player throw origin if drag is small.
      if (delta.length > 18) {
        _aimDir = delta.clone();
        if (_aimDir.x < 0.15) {
          _aimDir.x = 0.15; // keep lob toward enemy side
        }
      } else {
        _aimDir = ThrowPhysics.defaultAim(player.throwOrigin, enemy.hitCenter);
      }
    }
    chargeHud.aimDir = _aimDir;
    chargeHud.anchorWorld = player.throwOrigin;
  }

  void _onChargeEnd() {
    if (!_charging) return;
    _charging = false;
    chargeHud.visibleCharge = false;
    final charge = _charge.clamp(0.15, 1.0);
    _charge = 0;
    _dragStart = null;
    _fireSnowball(charge);
  }

  void _fireSnowball(double charge) {
    if (_waveCleared) return;

    final velocity = ThrowPhysics.launchVelocity(
      charge: charge,
      aimDirection: _aimDir,
    );
    player.showThrowPose();

    world.add(
      SnowballProjectile(
        sprite: snowballSprite,
        position: player.throwOrigin.clone(),
        velocity: velocity,
        targets: [enemy],
        owner: player,
        onHit: _onSnowballHit,
      ),
    );
  }

  void _onSnowballHit(SnowballProjectile ball, KidComponent target) {
    world.add(
      ImpactBurst(
        sprite: impactSprite,
        position: ball.position.clone(),
      ),
    );
    target.takeHit();
    if (target.isKo && !_waveCleared) {
      _showKoThenWaveClear();
    }
  }

  Future<void> _showKoThenWaveClear() async {
    _waveCleared = true;
    _banner?.removeFromParent();
    _banner = OverlayBanner(
      label: 'KO!',
      position: Vector2(worldWidth / 2, worldHeight / 2 - 40),
      fontSize: 56,
      color: const Color(0xFFFFE66D),
    );
    world.add(_banner!);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!isMounted) return;
    _banner?.removeFromParent();
    _banner = OverlayBanner(
      label: 'Wave clear!',
      position: Vector2(worldWidth / 2, worldHeight / 2 - 20),
      fontSize: 44,
      color: const Color(0xFFFFF8F0),
    );
    world.add(_banner!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_charging) {
      _charge = (_charge + dt / chargeSeconds).clamp(0.0, 1.0);
      chargeHud.charge = _charge;
      chargeHud.anchorWorld = player.throwOrigin;
    }
  }
}

typedef _ChargeStart = void Function(Vector2 worldPos);
typedef _ChargeUpdate = void Function(Vector2 worldPos);
typedef _ChargeEnd = void Function();

/// Full-screen invisible drag surface in world space.
class _ArenaInput extends PositionComponent with DragCallbacks {
  _ArenaInput({
    required Vector2 size,
    required this.onChargeStart,
    required this.onChargeUpdate,
    required this.onChargeEnd,
  }) : super(size: size, position: Vector2.zero(), priority: 50);

  final _ChargeStart onChargeStart;
  final _ChargeUpdate onChargeUpdate;
  final _ChargeEnd onChargeEnd;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    onChargeStart(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    onChargeUpdate(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    onChargeEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    onChargeEnd();
  }

  @override
  void render(Canvas canvas) {
    // Invisible hit target.
  }
}
