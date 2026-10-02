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
import 'arena_grid.dart';
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

  final MetaState meta;
  final VoidCallback? onExitToMenu;
  final FeelBus feel;
  final SaveStore _save;
  final SettingsStore _settings;
  final math.Random _rng;
  final Map<Season, SeasonKit> _kits = {};
  final Map<int, Sprite> _fortIntact = {};
  final Map<int, Sprite> _fortDamaged = {};
  Sprite? _fortCollapsed;

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

  /// Live charge for the bottom-of-screen power bar. 0 when not charging.
  final ValueNotifier<double> chargeListenable = ValueNotifier(0);
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
  bool _moving = false;
  bool _charging = false;
  bool _aimAdjusted = false;
  double _charge = 0;
  double _chargeHeld = 0;
  Vector2 _aimDir = Vector2(1, -0.4);
  Vector2 _aimTarget = Vector2(1000, 520);
  Vector2 _aimStickOrigin = Vector2(1000, 520);
  Vector2? _dragStart;
  Vector2? _moveTarget;
  ArenaCell _originCell = const ArenaCell(1, 4);
  _Banner _pendingBanner = _Banner.none;
  double _bannerTime = 0;
  OverlayBanner? _banner;
  KidComponent? _selected;

  double get charge => _charge;

  KidComponent? get selectedKid => _selected;

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
      _fortIntact[stage] = await loadSprite(
        'forts/fort_stage_${stage}_draft.png',
      );
      _fortDamaged[stage] = await loadSprite(
        'forts/fort_stage_${stage}_damaged_draft.png',
      );
    }
    _fortCollapsed = await loadSprite('forts/fort_collapsed_draft.png');

    final glow = await loadSprite('vfx/charge_glow_draft.png');

    _bg = SpriteComponent(
      sprite: _kit.background,
      size: Vector2(worldWidth, worldHeight),
      position: Vector2.zero(),
      priority: 0,
    );
    world.add(_bg);

    fort = FortComponent(
      sprite: _fortIntact[meta.fortStage]!,
      position: ArenaGrid.fortAnchor(),
      size: Vector2(270, 300),
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
      kid.position = ArenaGrid.slot(KidSide.player, i);
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
          moveSpeed: ThrowPhysics.kidMoveSpeed(),
          initialDelay: 0.35 + i * 0.5 + _rng.nextDouble() * 0.35,
          onFire: _onEnemyFire,
          isFighting: () => phase == MatchPhase.fight,
        ),
      );
    }

    fort.applyStage(
      nextStage: meta.fortStage,
      intactSprite: _fortIntact[meta.fortStage]!,
      damagedSprite: _fortDamaged[meta.fortStage]!,
      collapsedSprite: _fortCollapsed!,
    );
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
      position: ArenaGrid.slot(side, slot),
      size: Vector2.all(_kidSize),
      maxHp: CombatRules.hitsToKo,
    );
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

  /// Right-thumb Throw button. Hold to charge; the left thumb aims.
  void pressThrowButton() {
    if (phase != MatchPhase.fight || _charging) return;
    final kid = (_selected == null || _selected!.isKo)
        ? _firstLiving(players)
        : _selected;
    if (kid == null || kid.isKo) return;
    _setSelected(kid);
    _charging = true;
    _chargeHeld = 0;
    _charge = 0;
    _moveTarget = null;
    _moving = false;
    kid.setWalking(false);
    if (!_aimAdjusted) _aimAtNearest();
    kid.showChargePose();
    _syncChargeHud();
    _publishCharge();
  }

  void releaseThrowButton() {
    if (!_charging) return;
    _releaseThrow();
  }

  void _releaseThrow() {
    final kid = _selected;
    final charge = _charge < 0.15 ? 0.15 : (_charge > 1 ? 1.0 : _charge);
    _charging = false;
    _chargeHeld = 0;
    _charge = 0;
    chargeHud.visibleCharge = false;
    _publishCharge();
    if (kid == null || kid.isKo || phase != MatchPhase.fight) {
      kid?.clearChargePose();
      return;
    }
    final scale = CombatRules.projectileSpeedScale(meta.throwRank);
    final speed = ThrowPhysics.speedForCharge(charge, speedScale: scale);
    final from = kid.throwOrigin;
    final velocity =
        ThrowPhysics.launchToward(from: from, to: _aimTarget, speed: speed) ??
        ThrowPhysics.launchVelocity(
          charge: charge,
          aimDirection: _aimTarget - from,
          speedScale: scale,
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

  void debugPointerDown(Vector2 point) => _onPointerDown(point);

  void debugPointerMove(Vector2 point) => _onPointerMove(point);

  void debugPointerUp() => _onPointerUp();

  void _onPointerDown(Vector2 point) {
    if (phase != MatchPhase.fight) return;
    _pointerDown = true;
    _dragStart = point.clone();
    if (_charging) {
      _aimStickOrigin = _aimTarget.clone();
      return;
    }
    if (_selected == null || _selected!.isKo) {
      _setSelected(_firstLiving(players));
    }
    final near = _nearestLiving(players, point, maxDistance: 170);
    if (near != null) _setSelected(near);
    final kid = _selected;
    if (kid != null && !kid.isKo && point.x < ArenaGrid.enemyLeft) {
      _originCell = ArenaGrid.nearestCell(KidSide.player, kid.position);
      _moving = true;
    }
  }

  void _onPointerMove(Vector2 point) {
    if (!_pointerDown || phase != MatchPhase.fight) return;
    final start = _dragStart;
    if (start == null) return;
    final delta = point - start;
    if (_charging) {
      if (delta.length < 8) return;
      _aimAdjusted = true;
      final nudged = _aimStickOrigin + Vector2(delta.x * 1.2, delta.y * 1.35);
      _aimTarget = ArenaGrid.clampToRect(
        ArenaGrid.aimField(KidSide.enemy),
        nudged,
      );
      _syncChargeHud();
      return;
    }
    if (!_moving) return;
    final kid = _selected;
    if (kid == null || kid.isKo) return;
    final next = ArenaGrid.clampCell(
      _originCell.column + (delta.x / ArenaGrid.columnDrag).round(),
      _originCell.row + (delta.y / ArenaGrid.rowDrag).round(),
    );
    _moveTarget = ArenaGrid.cellCenter(KidSide.player, next.column, next.row);
  }

  void _onPointerUp() {
    _pointerDown = false;
    _moving = false;
    _dragStart = null;
    final kid = _selected;
    if (!_charging && kid != null && !kid.isKo && _moveTarget == null) {
      kid.setWalking(false);
    }
  }

  void _aimAtNearest() {
    final kid = _selected;
    final target = kid == null
        ? null
        : _nearestLiving(enemies, kid.throwOrigin);
    final fallback =
        ArenaGrid.cellCenter(KidSide.enemy, 1, 3) + Vector2(0, -68);
    _aimTarget = ArenaGrid.clampToRect(
      ArenaGrid.aimField(KidSide.enemy),
      target?.hitCenter.clone() ?? fallback,
    );
    _aimStickOrigin = _aimTarget.clone();
  }

  void _syncChargeHud() {
    final kid = _selected;
    if (kid == null) return;
    final aim = _aimTarget - kid.throwOrigin;
    if (aim.length2 > 1e-6) _aimDir = aim;
    chargeHud.visibleCharge = _charging;
    chargeHud.charge = _charge;
    chargeHud.aimDir = _aimDir;
    chargeHud.anchorWorld = kid.throwOrigin;
  }

  void _publishCharge() {
    final shown = _charging ? _charge.clamp(0.0, 1.0) : 0.0;
    if ((chargeListenable.value - shown).abs() < 0.001 &&
        !(shown == 0 && chargeListenable.value != 0)) {
      return;
    }
    chargeListenable.value = shown;
  }

  void _tickMove(double dt) {
    final kid = _selected;
    final target = _moveTarget;
    if (kid == null || target == null || kid.isKo || _charging) return;
    if (phase != MatchPhase.fight) return;
    final speed = ThrowPhysics.kidMoveSpeed(
      speedScale: CombatRules.projectileSpeedScale(meta.throwRank),
    );
    final delta = target - kid.position;
    final distance = delta.length;
    final step = speed * dt;
    if (distance <= step || distance < 0.8) {
      kid.position = target.clone();
      kid.setWalking(false);
      _moveTarget = null;
    } else {
      kid.position += delta / distance * step;
      kid.setWalking(true);
    }
  }

  void _endActiveThrow() {
    _pointerDown = false;
    _moving = false;
    _charging = false;
    _charge = 0;
    _chargeHeld = 0;
    _dragStart = null;
    _moveTarget = null;
    chargeHud.visibleCharge = false;
    _publishCharge();
    final kid = _selected;
    if (kid != null && !kid.isKo) {
      kid.setWalking(false);
      kid.clearChargePose();
    }
  }

  void _setSelected(KidComponent? kid) {
    if (kid != null && kid.isKo) kid = _firstLiving(players);
    _selected = kid;
    for (final player in players) {
      player.selected = identical(player, kid) && !player.isKo;
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
    _tickMove(dt);
    if (_charging) {
      final kid = _selected;
      if (kid == null || kid.isKo || phase != MatchPhase.fight) {
        _endActiveThrow();
      } else {
        _chargeHeld += dt;
        _charge = ThrowPhysics.chargeForHold(
          _chargeHeld,
          CombatRules.playerChargeSeconds(meta.throwRank),
        );
        kid.showChargePose();
        _syncChargeHud();
        _publishCharge();
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
