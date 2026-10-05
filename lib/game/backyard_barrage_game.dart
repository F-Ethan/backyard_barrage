import 'dart:async';
import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../feel/feel_bus.dart';
import '../meta/difficulty.dart';
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

/// Landscape backyard arena: charge on the swivel, lob, then shop between waves.
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
  late FortComponent enemyFort;
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

  /// Right-hand share of the screen. A hold there charges; release throws.
  static const double chargeScreenFraction = 2 / 3;

  /// A touch this close to a kid's body selects them instead of stepping.
  static const double selectRadius = 72;

  bool _chargeHolding = false;
  bool _moveHolding = false;
  bool _charging = false;
  double _charge = 0;
  double _chargeHeld = 0;
  double _swivel = 0;
  Vector2 _aimDir = Vector2(1, 0);
  Vector2? _moveTarget;
  ArenaCell? _moveGoal;
  _Banner _pendingBanner = _Banner.none;
  double _bannerTime = 0;
  OverlayBanner? _banner;
  KidComponent? _selected;

  double get charge => _charge;

  bool get isCharging => _charging;

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
      side: KidSide.player,
      sprite: _fortIntact[meta.fortStage]!,
      position: ArenaGrid.fortAnchor(),
      size: Vector2(270, 300),
    );
    world.add(fort);
    enemyFort = FortComponent(
      side: KidSide.enemy,
      sprite: _fortIntact[1]!,
      position: ArenaGrid.fortAnchor(KidSide.enemy),
      size: Vector2(270, 300),
    );
    world.add(enemyFort);

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

    while (players.length > meta.crewSize) {
      players.removeLast().removeFromParent();
    }
    while (players.length < meta.crewSize) {
      final kid = _makeKid(KidSide.player, players.length);
      players.add(kid);
      world.add(kid);
    }
    for (var i = 0; i < players.length; i++) {
      final kid = players[i];
      kid.position = ArenaGrid.slot(KidSide.player, i);
      kid.syncDepth();
      kid.revive();
    }
    _setSelected(_firstLiving(players));
    _ensureAllyBrains();

    final count = CombatRules.enemyCountForWave(wave);
    for (var i = 0; i < count; i++) {
      final kid = _makeKid(KidSide.enemy, i);
      enemies.add(kid);
      world.add(kid);
      final profile = _tuning();
      final gap = profile.throwGap(_rng.nextDouble());
      final stagger = (gap * (0.75 + i * 0.1)).clamp(
        profile.throwGapMin,
        profile.throwGapMax,
      );
      kid.add(
        EnemyController(
          host: kid,
          players: players,
          rivals: enemies,
          wave: wave,
          rng: _rng,
          tuning: _tuning,
          initialDelay: stagger,
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
    enemyFort.applyStage(
      nextStage: 1,
      intactSprite: _fortIntact[1]!,
      damagedSprite: _fortDamaged[1]!,
      collapsedSprite: _fortCollapsed!,
    );
    fort.placeOnRow(ArenaGrid.rollFortRow(_rng));
    enemyFort.placeOnRow(ArenaGrid.rollFortRow(_rng));
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
      size: Vector2.all(ArenaGrid.kidSize),
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
    meta.resetRun();
    unawaited(persist());
    _publishHud();
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

  DifficultyTuning _tuning() =>
      DifficultyTuning.of(feel.settings.difficulty, wave: wave);

  void _onEnemyFire(
    KidComponent enemy,
    KidComponent? target,
    double rangeScale,
  ) {
    if (phase != MatchPhase.fight || enemy.isKo) return;
    feel.enemyReleased();
    final cell = ArenaGrid.nearestCell(KidSide.enemy, enemy.position);
    final targetRow = target == null
        ? cell.row
        : ArenaGrid.nearestCell(target.side, target.position).row;
    final distance = target == null
        ? 640.0
        : (enemy.throwOrigin.x - target.hitCenter.x).abs();
    final lob = ThrowPhysics.planEnemyLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      targetRow: targetRow,
      distance: distance,
      rangeScale: rangeScale,
      facingRight: false,
      originY: enemy.throwOrigin.y,
    );
    _spawnShot(owner: enemy, lob: lob, targets: players);
  }

  void _onAllyFire(KidComponent ally, KidComponent? target, double rangeScale) {
    if (phase != MatchPhase.fight || ally.isKo || identical(ally, _selected)) {
      return;
    }
    feel.playerReleased();
    final cell = ArenaGrid.nearestCell(KidSide.player, ally.position);
    final targetRow = target == null
        ? cell.row
        : ArenaGrid.nearestCell(target.side, target.position).row;
    final distance = target == null
        ? 640.0
        : (ally.throwOrigin.x - target.hitCenter.x).abs();
    final lob = ThrowPhysics.planEnemyLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      targetRow: targetRow,
      distance: distance,
      rangeScale: rangeScale,
      facingRight: true,
      originY: ally.throwOrigin.y,
    );
    _spawnShot(owner: ally, lob: lob, targets: enemies);
  }

  void _ensureAllyBrains() {
    for (var i = 0; i < players.length; i++) {
      final kid = players[i];
      if (kid.children.whereType<EnemyController>().isNotEmpty) continue;
      final profile = DifficultyTuning.of(Difficulty.easy, wave: wave);
      kid.add(
        EnemyController(
          host: kid,
          players: enemies,
          rivals: players,
          wave: wave,
          rng: _rng,
          tuning: () => DifficultyTuning.of(Difficulty.easy, wave: wave),
          initialDelay: profile.throwGap((0.35 + i * 0.2).clamp(0.0, 1.0)),
          onFire: _onAllyFire,
          isFighting: () => phase == MatchPhase.fight,
          side: KidSide.player,
          approachColumn: 1,
          isManual: () => identical(_selected, kid),
          currentWave: () => wave,
        ),
      );
    }
  }

  /// Canvas point to the backyard. The fight overlay uses the same space
  /// as the letterboxed game.
  Vector2 screenToWorld(Offset local) {
    return camera.globalToLocal(Vector2(local.dx, local.dy));
  }

  /// Hold on the right third of the screen. Release throws.
  void pressChargeZone() {
    if (phase != MatchPhase.fight || _chargeHolding) return;
    final kid = _readyThrower();
    if (kid == null) return;
    _chargeHolding = true;
    _moveHolding = false;
    _moveGoal = null;
    _setSelected(kid);
    _beginCharge();
  }

  void releaseChargeZone() {
    if (!_chargeHolding) return;
    _chargeHolding = false;
    if (_charging) _releaseThrow();
  }

  /// Left side of the screen. A tap steps one cell toward the touch.
  /// A hold keeps stepping until the finger lifts or the kid arrives.
  void pressMoveZone(Vector2 world) {
    if (phase != MatchPhase.fight || _charging) return;
    final tapped = _nearestLiving(players, world, maxDistance: selectRadius);
    if (tapped != null) {
      _setSelected(tapped);
      _moveHolding = false;
      _moveGoal = null;
      return;
    }
    _moveHolding = true;
    _moveGoal = ArenaGrid.nearestCell(KidSide.player, world);
    _queueGridStep();
  }

  void dragMoveZone(Vector2 world) {
    if (!_moveHolding || _charging || phase != MatchPhase.fight) return;
    _moveGoal = ArenaGrid.nearestCell(KidSide.player, world);
    _queueGridStep();
  }

  void releaseMoveZone() {
    _moveHolding = false;
  }

  void _beginCharge() {
    final kid = _selected;
    if (kid == null || kid.isKo || kid.isStunned) return;
    if (_charging) {
      _syncChargeHud();
      _publishCharge();
      return;
    }
    _charging = true;
    _chargeHeld = 0;
    _charge = ThrowPhysics.minThrowCharge;
    _swivel = 0;
    _moveTarget = null;
    _moveHolding = false;
    kid.setWalking(false);
    _aimDir = ThrowPhysics.aimForElevation(0, facingRight: true);
    kid.showChargePose();
    _syncChargeHud();
    _publishCharge();
  }

  void _releaseThrow() {
    final kid = _selected;
    final charge = ThrowPhysics.chargeForHold(
      _chargeHeld,
      CombatRules.playerChargeSeconds(meta.throwRank),
    );
    _charging = false;
    _chargeHeld = 0;
    _charge = 0;
    _swivel = 0;
    chargeHud.visibleCharge = false;
    _publishCharge();
    if (kid == null || kid.isKo || kid.isStunned || phase != MatchPhase.fight) {
      kid?.clearChargePose();
      return;
    }
    final cell = ArenaGrid.nearestCell(KidSide.player, kid.position);
    final lob = ThrowPhysics.planPlayerLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      aimDirection: _aimDir,
      charge: charge,
      facingRight: true,
      speedScale: CombatRules.projectileSpeedScale(meta.throwRank),
      originY: kid.throwOrigin.y,
    );
    kid.showThrowPose();
    feel.playerReleased();
    _spawnShot(owner: kid, lob: lob, targets: enemies);
  }

  void _spawnShot({
    required KidComponent owner,
    required RowLob lob,
    required List<KidComponent> targets,
  }) {
    world.add(
      LobProjectile(
        sprite: _kit.projectile,
        position: owner.throwOrigin.clone(),
        velocity: lob.velocity.clone(),
        targets: targets,
        owner: owner,
        blockedByFort: true,
        forts: [fort, enemyFort],
        friendlyFortDamage: _tuning().friendlyFortDamage,
        groundTrack: lob.groundTrack,
        throwerRow: lob.throwerRow,
        throwerColumn: lob.throwerColumn,
        peakRow: lob.peakRow,
        landingRow: lob.landingRow,
        apexRise: lob.apexRise,
        landingDrop: lob.landingDrop,
        launchVy: lob.velocity.y,
        scripted: lob.scripted,
        travelSpeed: lob.travelSpeed,
        flightRange: lob.range,
        apexFraction: lob.apexFraction,
        settleFraction: lob.settleFraction,
        landingY: lob.landingY,
        apexY: lob.apexY,
        onHit: _onKidHit,
        onFortHit: _onFortHit,
        onGround: _onGroundMiss,
      ),
    );
  }

  void _onKidHit(LobProjectile shot, KidComponent target) {
    _burst(shot.position);
    if (phase != MatchPhase.fight || target.isKo) return;
    final selectedHit = identical(target, _selected);
    target.takeHit();
    feel.kidHit(knockedOut: target.isKo, season: meta.season);
    if (selectedHit) {
      _endActiveThrow();
      if (target.isKo || target.isStunned) {
        _setSelected(_firstReady(players) ?? _firstLiving(players));
      }
    }
    resolveKnockouts();
  }

  void _onFortHit(LobProjectile shot) {
    _burst(shot.position);
    feel.impact(meta.season);
    if (phase != MatchPhase.fight) return;
    final cover = shot.struckFort;
    if (shot.fortDamage && cover != null) cover.takeHit();
  }

  void _onGroundMiss(LobProjectile shot) {
    _burst(shot.position);
    feel.impact(meta.season);
  }

  void _burst(Vector2 at) {
    world.add(ImpactBurst(sprite: _kit.impact, position: at.clone()));
  }

  void debugPointerDown(Vector2 point) => _onPointerDown(point);

  void debugPointerMove(Vector2 point) => _onPointerMove(point);

  void debugPointerUp() => _onPointerUp();

  void _onPointerDown(Vector2 point) => pressMoveZone(point);

  void _onPointerMove(Vector2 point) => dragMoveZone(point);

  void _onPointerUp() => releaseMoveZone();

  void _syncChargeHud() {
    final kid = _selected;
    if (kid == null) return;
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
    if (kid == null || kid.isKo || phase != MatchPhase.fight) return;
    if (kid.isStunned || _charging) {
      if (_moveTarget != null) {
        _moveTarget = null;
        _moveHolding = false;
        kid.setWalking(false);
      }
      return;
    }
    final arrived = _advanceStep(kid, dt);
    if (arrived && _moveTarget == null && _moveHolding) {
      _queueGridStep();
    }
  }

  /// Moves toward the current cell. Returns true when that consumed the
  /// frame, including the frame the kid arrives, so one update cannot
  /// chain into a second cell.
  bool _advanceStep(KidComponent kid, double dt) {
    final target = _moveTarget;
    if (target == null) return false;
    final scale = _tuning().playerMoveScale;
    final cap = ThrowPhysics.kidMoveSpeed() * (scale <= 0 ? 1.0 : scale);
    final delta = target - kid.position;
    final distance = delta.length;
    final step = cap * dt;
    if (distance <= step || distance < 0.8) {
      kid.position = target.clone();
      kid.setWalking(false);
      _moveTarget = null;
    } else {
      kid.position += delta / distance * step;
      kid.setWalking(true);
    }
    kid.syncDepth();
    return true;
  }

  /// One cell toward the finger: forward, back, up, or down. Never two
  /// cells, and never both axes in the same step. A tap cannot chain.
  void _queueGridStep() {
    if (_moveTarget != null) return;
    final kid = _selected;
    final goal = _moveGoal;
    if (kid == null || goal == null || kid.isKo || kid.isStunned || _charging) {
      return;
    }
    final cell = ArenaGrid.nearestCell(KidSide.player, kid.position);
    final dColumn = goal.column - cell.column;
    final dRow = goal.row - cell.row;
    if (dColumn == 0 && dRow == 0) return;
    final goalPoint = ArenaGrid.cellCenter(
      KidSide.player,
      goal.column,
      goal.row,
    );
    final columnFirst =
        (goalPoint.x - kid.position.x).abs() >=
        (goalPoint.y - kid.position.y).abs();
    final options = columnFirst
        ? <(int, int)>[(dColumn.sign, 0), (0, dRow.sign)]
        : <(int, int)>[(0, dRow.sign), (dColumn.sign, 0)];
    for (final (stepColumn, stepRow) in options) {
      if (stepColumn == 0 && stepRow == 0) continue;
      final nextColumn = cell.column + stepColumn;
      final nextRow = cell.row + stepRow;
      if (nextColumn < 0 || nextColumn >= ArenaGrid.columnsPerSide) continue;
      if (nextRow < 0 || nextRow >= ArenaGrid.rows) continue;
      if (_playerCellTaken(nextColumn, nextRow, kid)) continue;
      final dest = ArenaGrid.cellCenter(KidSide.player, nextColumn, nextRow);
      if (dest.distanceTo(kid.position) < 1) continue;
      _moveTarget = dest;
      kid.setWalking(true);
      return;
    }
  }

  bool _playerCellTaken(int column, int row, KidComponent self) {
    for (final kid in players) {
      if (identical(kid, self) || kid.isKo) continue;
      final cell = ArenaGrid.nearestCell(KidSide.player, kid.position);
      if (cell.column == column && cell.row == row) return true;
    }
    return false;
  }

  void _endActiveThrow() {
    _chargeHolding = false;
    _moveHolding = false;
    _moveGoal = null;
    _charging = false;
    _charge = 0;
    _chargeHeld = 0;
    _swivel = 0;
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

  /// A kid who can still step and throw. Skips KO and stun.
  KidComponent? _firstReady(List<KidComponent> kids) {
    for (final kid in kids) {
      if (!kid.isKo && !kid.isStunned) return kid;
    }
    return null;
  }

  KidComponent? _readyThrower() {
    final selected = _selected;
    if (selected != null && !selected.isKo && !selected.isStunned) {
      return selected;
    }
    return _firstReady(players);
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
      if (kid == null ||
          kid.isKo ||
          kid.isStunned ||
          phase != MatchPhase.fight) {
        _endActiveThrow();
      } else {
        _chargeHeld += dt;
        _charge = ThrowPhysics.chargeForHold(
          _chargeHeld,
          CombatRules.playerChargeSeconds(meta.throwRank),
        );
        _swivel = ThrowPhysics.swivelElevation(_chargeHeld);
        _aimDir = ThrowPhysics.aimForElevation(_swivel, facingRight: true);
        kid.showChargeYaw(ThrowPhysics.chargeYaw(_swivel));
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
        priority: 3000,
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
