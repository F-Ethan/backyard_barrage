import 'dart:async';
import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../feel/feel_bus.dart';
import '../meta/game_settings.dart';
import '../meta/meta_state.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/season.dart';
import '../seasons/season_kit.dart';
import 'combat_rules.dart';
import 'components/charge_indicator.dart';
import 'components/enemy_controller.dart';
import 'components/fort_component.dart';
import 'components/impact_burst.dart';
import 'components/kid_component.dart';
import 'components/lob_projectile.dart';
import 'components/overlay_banner.dart';
import 'throw_physics.dart';

enum MatchPhase { fight, clearing, defeat, shop, paused }

enum _Gesture { idle, undecided, move, charge, suppressed }

enum _Banner { none, waveKo, waveDone, defeatKo }

/// Landscape backyard arena: charge, aim, lob, then shop between waves.
class BackyardBarrageGame extends FlameGame {
  BackyardBarrageGame({
    required this.meta,
    SaveStore? saveStore,
    SettingsStore? settingsStore,
    FeelBus? feel,
    math.Random? random,
    this.onExitToMenu,
  }) : _save = saveStore ?? SaveStore(),
       _settings = settingsStore ?? SettingsStore(),
       feel = feel ?? FeelBus(),
       _rng = random ?? math.Random(),
       super(
         camera: CameraComponent.withFixedResolution(
           width: worldWidth,
           height: worldHeight,
           viewfinder: Viewfinder()
             ..anchor = Anchor.topLeft
             ..position = Vector2.zero(),
         ),
       );

  /// Design resolution of the backyard art. The camera letterboxes this
  /// rectangle onto the device so phones do not crop it 1:1.
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double _kidSize = 152;
  static const double _playerLaneMin = 120;
  static const double _playerLaneMax = 470;
  static const double _enemyLaneMin = 860;
  static const double _enemyLaneMax = 1180;

  final MetaState meta;
  final VoidCallback? onExitToMenu;
  final FeelBus feel;
  final SaveStore _save;
  final SettingsStore _settings;
  final math.Random _rng;
  final Map<Season, SeasonKit> _kits = {};
  final Map<int, Sprite> _fortSprites = {};

  final List<KidComponent> players = [];
  final List<KidComponent> enemies = [];

  late FortComponent fort;
  late ChargeIndicator chargeHud;
  late SeasonKit _kit;
  late SpriteComponent _bg;

  MatchPhase _phase = MatchPhase.fight;
  final ValueNotifier<MatchPhase> phaseListenable = ValueNotifier(
    MatchPhase.fight,
  );

  /// Bumps when hearts, coins, fort HP, or the wave number change so the
  /// screen-space HUD can rebuild without living in the scaled world.
  final ValueNotifier<int> hudRevision = ValueNotifier(0);
  int _hudSignature = 0;
  MatchPhase _resumePhase = MatchPhase.fight;

  MatchPhase get phase => _phase;

  set phase(MatchPhase value) {
    _phase = value;
    if (phaseListenable.value != value) {
      phaseListenable.value = value;
    }
  }

  int wave = 1;
  int lastReward = 0;

  bool _pointerDown = false;
  bool _charging = false;
  bool _aimAdjusted = false;
  double _charge = 0;
  double _held = 0;
  Vector2 _aimDir = Vector2(1, -0.55);
  Vector2? _dragStart;
  Vector2? _lastDrag;
  _Gesture _gesture = _Gesture.idle;
  _Banner _pendingBanner = _Banner.none;
  double _bannerTime = 0;
  OverlayBanner? _banner;
  KidComponent? _selected;

  @override
  Color backgroundColor() => meta.season == Season.summer
      ? const Color(0xFF87CEEB)
      : const Color(0xFFA8D4F0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Keep the full 1280×720 yard in frame. FixedResolutionViewport scales
    // that rectangle to fit the canvas (side bars on wide phones) instead of
    // showing a 1:1 crop of the top-left, which hides kids on short screens.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 1;

    for (final season in Season.values) {
      _kits[season] = await loadSeasonKit(this, season);
    }
    _kit = _kits[meta.season]!;

    for (final stage in [1, 2, 3]) {
      _fortSprites[stage] = await loadSprite(
        'forts/fort_stage_${stage}_draft.png',
      );
    }

    final glow = await loadSprite('vfx/charge_glow_draft.png');

    _bg = SpriteComponent(
      sprite: _kit.background,
      size: Vector2(worldWidth, worldHeight),
      position: Vector2.zero(),
      priority: 0,
    );
    world.add(_bg);

    fort = FortComponent(
      sprite: _fortSprites[meta.fortStage]!,
      position: Vector2(280, 670),
      size: Vector2.all(360),
    );
    world.add(fort);

    chargeHud = ChargeIndicator(glowSprite: glow);
    world.add(chargeHud);
    world.add(_ArenaInput(this));
    startWave();
    overlays.add('hud');
  }

  Future<void> persist() => _save.save(meta);

  Future<void> commitSettings(GameSettings next) async {
    feel.apply(next);
    await _settings.save(next);
    await feel.syncMusic(battleSeason: meta.season);
  }

  void pauseMatch() {
    if (phase != MatchPhase.fight && phase != MatchPhase.clearing) return;
    _resumePhase = phase;
    _endActiveThrow();
    phase = MatchPhase.paused;
    if (!overlays.isActive('pause')) overlays.add('pause');
    if (!paused) pauseEngine();
  }

  void resumeMatch() {
    if (phase != MatchPhase.paused) return;
    closeSettings();
    if (overlays.isActive('pause')) overlays.remove('pause');
    phase = _resumePhase;
    if (paused) resumeEngine();
  }

  void openSettings() {
    if (phase != MatchPhase.paused) return;
    if (!overlays.isActive('settings')) overlays.add('settings');
  }

  void closeSettings() {
    if (overlays.isActive('settings')) overlays.remove('settings');
  }

  Future<void> setSeason(Season season) async {
    if (meta.season == season) return;
    meta.season = season;
    final kit = _kits[season];
    if (kit != null && isLoaded) _applyKit(kit);
    await persist();
    await feel.enterBattle(season);
  }

  void _applyKit(SeasonKit kit) {
    _kit = kit;
    _bg.sprite = kit.background;
    for (final kid in players) {
      kid.applyPoses(kit.playerPoses);
    }
    for (final kid in enemies) {
      kid.applyPoses(kit.enemyPoses);
    }
  }

  void startWave() {
    _pendingBanner = _Banner.none;
    _bannerTime = 0;
    _clearBanner();
    _endActiveThrow();
    _clearShots();
    _clearEnemies();
    phase = MatchPhase.fight;

    while (players.length < meta.crewSize) {
      final kid = _makeKid(KidSide.player, players.length);
      players.add(kid);
      world.add(kid);
    }
    for (var i = 0; i < players.length; i++) {
      final kid = players[i];
      kid.position = _playerSlot(i);
      kid.revive();
    }
    _setSelected(_firstLiving(players));

    final count = CombatRules.enemyCountForWave(wave);
    for (var i = 0; i < count; i++) {
      final kid = _makeKid(KidSide.enemy, i);
      enemies.add(kid);
      world.add(kid);
      kid.add(
        EnemyController(
          host: kid,
          players: players,
          wave: wave,
          rng: _rng,
          laneMin: _enemyLaneMin,
          laneMax: _enemyLaneMax,
          initialDelay: 0.35 + i * 0.5 + _rng.nextDouble() * 0.35,
          onFire: _onEnemyFire,
          isFighting: () => phase == MatchPhase.fight,
        ),
      );
    }

    fort.applyStage(meta.fortStage, _fortSprites[meta.fortStage]!);
    _publishHud();
    unawaited(feel.enterBattle(meta.season));
  }

  void _publishHud() {
    var signature = Object.hash(
      wave,
      meta.coins,
      fort.hp,
      fort.maxHp,
      players.length,
      enemies.length,
    );
    for (final kid in players) {
      signature = Object.hash(signature, kid.hp);
    }
    for (final kid in enemies) {
      signature = Object.hash(signature, kid.hp);
    }
    if (signature == _hudSignature) return;
    _hudSignature = signature;
    hudRevision.value++;
  }

  KidComponent _makeKid(KidSide side, int slot) {
    final player = side == KidSide.player;
    return KidComponent(
      side: side,
      poses: player ? _kit.playerPoses : _kit.enemyPoses,
      position: player ? _playerSlot(slot) : _enemySlot(slot),
      size: Vector2.all(_kidSize),
      maxHp: CombatRules.hitsToKo,
    );
  }

  Vector2 _playerSlot(int index) {
    return switch (index) {
      0 => Vector2(240, 648),
      1 => Vector2(150, 600),
      _ => Vector2(330, 610),
    };
  }

  Vector2 _enemySlot(int index) {
    return switch (index) {
      0 => Vector2(1040, 648),
      1 => Vector2(900, 600),
      _ => Vector2(1160, 615),
    };
  }

  void _clearEnemies() {
    for (final enemy in List<KidComponent>.of(enemies)) {
      enemy.removeFromParent();
    }
    enemies.clear();
  }

  void _clearShots() {
    for (final shot in world.children.whereType<LobProjectile>().toList()) {
      shot.removeFromParent();
    }
  }

  void continueFromShop() {
    if (phase != MatchPhase.shop) return;
    if (overlays.isActive('shop')) overlays.remove('shop');
    if (paused) resumeEngine();
    wave += 1;
    startWave();
  }

  void retryFromDefeat() {
    if (overlays.isActive('defeat')) overlays.remove('defeat');
    if (paused) resumeEngine();
    wave = 1;
    startWave();
  }

  void exitToMenu() {
    overlays.clear();
    if (paused) resumeEngine();
    unawaited(persist());
    onExitToMenu?.call();
  }

  void resolveKnockouts() {
    if (phase != MatchPhase.fight) return;
    final livingPlayers = players.where((kid) => !kid.isKo).length;
    final livingEnemies = enemies.where((kid) => !kid.isKo).length;
    switch (CombatRules.roundOutcome(
      livingPlayers: livingPlayers,
      livingEnemies: livingEnemies,
    )) {
      case RoundOutcome.defeat:
        _beginDefeat();
      case RoundOutcome.waveClear:
        _beginWaveClear();
      case RoundOutcome.ongoing:
        break;
    }
  }

  void _beginWaveClear() {
    if (phase != MatchPhase.fight) return;
    phase = MatchPhase.clearing;
    _endActiveThrow();
    _clearShots();
    lastReward = MetaState.coinsForWave(wave);
    meta.coins += lastReward;
    meta.noteWaveCleared(wave);
    unawaited(persist());
    feel.waveCleared();
    _showBanner('KO!', fontSize: 56, color: const Color(0xFFFFE66D));
    _pendingBanner = _Banner.waveKo;
    _bannerTime = 0.65;
  }

  void _beginDefeat() {
    if (phase == MatchPhase.defeat || phase == MatchPhase.shop) return;
    phase = MatchPhase.defeat;
    _endActiveThrow();
    _clearShots();
    feel.defeated();
    _showBanner(
      'Crew down',
      subtitle: 'Every kid is down.',
      fontSize: 48,
      color: const Color(0xFF1A2332),
    );
    _pendingBanner = _Banner.defeatKo;
    _bannerTime = 0.6;
  }

  void _advanceBanner() {
    switch (_pendingBanner) {
      case _Banner.waveKo:
        _showBanner(
          'Wave $wave clear!',
          subtitle: '+$lastReward coins',
          fontSize: 42,
          color: const Color(0xFF1A2332),
        );
        _pendingBanner = _Banner.waveDone;
        _bannerTime = 0.55;
      case _Banner.waveDone:
        _pendingBanner = _Banner.none;
        _clearBanner();
        phase = MatchPhase.shop;
        overlays.add('shop');
        pauseEngine();
      case _Banner.defeatKo:
        _pendingBanner = _Banner.none;
        _clearBanner();
        overlays.add('defeat');
        pauseEngine();
      case _Banner.none:
        break;
    }
  }

  void _showBanner(
    String label, {
    String? subtitle,
    required double fontSize,
    required Color color,
  }) {
    _clearBanner();
    _banner = OverlayBanner(
      label: label,
      subtitle: subtitle,
      position: Vector2(worldWidth / 2, worldHeight / 2 - 30),
      fontSize: fontSize,
      color: color,
    );
    world.add(_banner!);
  }

  void _clearBanner() {
    _banner?.removeFromParent();
    _banner = null;
  }

  void _onEnemyFire(KidComponent enemy, Vector2 aim, double charge) {
    if (phase != MatchPhase.fight || enemy.isKo) return;
    feel.enemyReleased();
    final velocity = ThrowPhysics.launchVelocity(
      charge: charge,
      aimDirection: aim,
    );
    _spawnShot(
      owner: enemy,
      velocity: velocity,
      targets: players,
      blockedByFort: true,
    );
  }

  void _releaseThrow() {
    final kid = _selected;
    final charge = _charge < 0.15 ? 0.15 : (_charge > 1 ? 1.0 : _charge);
    _charging = false;
    _charge = 0;
    chargeHud.visibleCharge = false;
    if (kid == null || kid.isKo || phase != MatchPhase.fight) {
      kid?.clearChargePose();
      return;
    }
    final velocity = ThrowPhysics.launchVelocity(
      charge: charge,
      aimDirection: _aimDir,
      speedScale: CombatRules.projectileSpeedScale(meta.throwRank),
    );
    kid.showThrowPose();
    feel.playerReleased();
    _spawnShot(
      owner: kid,
      velocity: velocity,
      targets: enemies,
      blockedByFort: false,
    );
  }

  void _spawnShot({
    required KidComponent owner,
    required Vector2 velocity,
    required List<KidComponent> targets,
    required bool blockedByFort,
  }) {
    world.add(
      LobProjectile(
        sprite: _kit.projectile,
        position: owner.throwOrigin.clone(),
        velocity: velocity,
        targets: targets,
        owner: owner,
        blockedByFort: blockedByFort,
        fort: blockedByFort ? fort : null,
        onHit: _onKidHit,
        onFortHit: _onFortHit,
      ),
    );
  }

  void _onKidHit(LobProjectile shot, KidComponent target) {
    _burst(shot.position);
    if (phase != MatchPhase.fight || target.isKo) return;
    final knockedOut = target.hp <= 1;
    feel.kidHit(knockedOut: knockedOut, season: meta.season);
    final selectedHit = identical(target, _selected);
    target.takeHit();
    if (selectedHit) {
      _endActiveThrow();
      if (target.isKo) _setSelected(_firstLiving(players));
    }
    resolveKnockouts();
  }

  void _onFortHit(LobProjectile shot) {
    _burst(shot.position);
    feel.impact(meta.season);
    if (phase != MatchPhase.fight) return;
    fort.takeHit();
  }

  void _burst(Vector2 at) {
    world.add(ImpactBurst(sprite: _kit.impact, position: at.clone()));
  }

  void _onPointerDown(Vector2 point) {
    if (phase != MatchPhase.fight) return;
    _pointerDown = true;
    _held = 0;
    _dragStart = point.clone();
    _lastDrag = point.clone();
    _gesture = _Gesture.undecided;
    _aimAdjusted = false;
    final near = _nearestLiving(players, point, maxDistance: 150);
    if (near != null) _setSelected(near);
    _selected ??= _firstLiving(players);
  }

  void _onPointerMove(Vector2 point) {
    if (!_pointerDown || phase != MatchPhase.fight) return;
    if (_gesture == _Gesture.suppressed) return;
    final start = _dragStart;
    if (start == null) return;
    final total = point - start;
    if (_gesture == _Gesture.undecided) {
      if (total.length < 18) return;
      final horizontal =
          total.x.abs() > total.y.abs() * 1.2 && total.y.abs() < 110;
      if (horizontal) {
        _gesture = _Gesture.move;
        _selected?.setWalking(true);
      } else {
        _aimDir = _aimFromDrag(total);
        _aimAdjusted = true;
        _beginCharge();
      }
    }
    if (_gesture == _Gesture.move) {
      final kid = _selected;
      final last = _lastDrag;
      if (kid != null && !kid.isKo && last != null) {
        final next = kid.position.x + (point.x - last.x);
        if (next < _playerLaneMin) {
          kid.position.x = _playerLaneMin;
        } else if (next > _playerLaneMax) {
          kid.position.x = _playerLaneMax;
        } else {
          kid.position.x = next;
        }
        kid.setWalking(true);
      }
    } else if (_gesture == _Gesture.charge && total.length > 18) {
      _aimDir = _aimFromDrag(total);
      _aimAdjusted = true;
      chargeHud.aimDir = _aimDir;
    }
    _lastDrag = point.clone();
  }

  void _onPointerUp() {
    if (!_pointerDown && !_charging) return;
    final fire =
        _pointerDown &&
        _gesture == _Gesture.charge &&
        _charging &&
        phase == MatchPhase.fight;
    _pointerDown = false;
    _gesture = _Gesture.idle;
    _aimAdjusted = false;
    _dragStart = null;
    _lastDrag = null;
    _held = 0;
    if (fire) {
      _releaseThrow();
      return;
    }
    _charging = false;
    _charge = 0;
    chargeHud.visibleCharge = false;
    final kid = _selected;
    if (kid != null && !kid.isKo) {
      kid.setWalking(false);
      kid.clearChargePose();
    }
  }

  void _beginCharge() {
    if (_charging ||
        _gesture == _Gesture.move ||
        _gesture == _Gesture.suppressed) {
      return;
    }
    final kid = _selected;
    if (kid == null || kid.isKo || phase != MatchPhase.fight) return;
    _gesture = _Gesture.charge;
    _charging = true;
    if (_charge < 0.12) _charge = 0.12;
    if (!_aimAdjusted) {
      final target = _nearestLiving(enemies, kid.throwOrigin);
      _aimDir = target == null
          ? Vector2(1, -0.55)
          : ThrowPhysics.defaultAim(kid.throwOrigin, target.hitCenter);
    }
    kid.showChargePose();
    _syncChargeHud();
  }

  Vector2 _aimFromDrag(Vector2 delta) {
    final aim = delta.clone();
    if (aim.x < 0.2) aim.x = 0.2;
    return aim;
  }

  void _syncChargeHud() {
    final kid = _selected;
    if (kid == null) return;
    chargeHud.visibleCharge = true;
    chargeHud.charge = _charge;
    chargeHud.aimDir = _aimDir;
    chargeHud.anchorWorld = kid.throwOrigin;
  }

  void _endActiveThrow() {
    _pointerDown = false;
    _charging = false;
    _charge = 0;
    _held = 0;
    _gesture = _Gesture.idle;
    _aimAdjusted = false;
    _dragStart = null;
    _lastDrag = null;
    chargeHud.visibleCharge = false;
    final kid = _selected;
    if (kid != null && !kid.isKo) {
      kid.setWalking(false);
      kid.clearChargePose();
    }
  }

  void _setSelected(KidComponent? kid) {
    _selected = kid;
    for (final player in players) {
      player.selected = identical(player, kid);
    }
  }

  KidComponent? _firstLiving(List<KidComponent> kids) {
    for (final kid in kids) {
      if (!kid.isKo) return kid;
    }
    return null;
  }

  KidComponent? _nearestLiving(
    List<KidComponent> kids,
    Vector2 point, {
    double? maxDistance,
  }) {
    KidComponent? best;
    var bestDistance = maxDistance == null
        ? double.infinity
        : maxDistance * maxDistance;
    for (final kid in kids) {
      if (kid.isKo) continue;
      final distance = kid.hitCenter.distanceToSquared(point);
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = kid;
      }
    }
    return best;
  }

  @override
  void update(double dt) {
    if (paused || phase == MatchPhase.paused) return;
    super.update(dt);
    if (_pointerDown &&
        _gesture == _Gesture.undecided &&
        phase == MatchPhase.fight) {
      _held += dt;
      if (_held >= 0.16) _beginCharge();
    }
    if (_charging) {
      final kid = _selected;
      if (kid == null || kid.isKo || phase != MatchPhase.fight) {
        _endActiveThrow();
      } else {
        final next =
            _charge + dt / CombatRules.playerChargeSeconds(meta.throwRank);
        _charge = next > 1 ? 1 : next;
        kid.showChargePose();
        _syncChargeHud();
      }
    }
    if (_pendingBanner != _Banner.none) {
      _bannerTime -= dt;
      if (_bannerTime <= 0) _advanceBanner();
    }
    _publishHud();
  }
}

class _ArenaInput extends PositionComponent with DragCallbacks {
  _ArenaInput(this.game)
    : super(
        size: Vector2(
          BackyardBarrageGame.worldWidth,
          BackyardBarrageGame.worldHeight,
        ),
        position: Vector2.zero(),
        priority: 40,
      );

  final BackyardBarrageGame game;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game._onPointerDown(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game._onPointerMove(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game._onPointerUp();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game._onPointerUp();
  }

  @override
  void render(Canvas canvas) {}
}
