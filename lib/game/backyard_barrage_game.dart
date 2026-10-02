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

  bool _pointerDown = false;
  bool _yardHolding = false;
  bool _stickHolding = false;
  bool _charging = false;
  bool _aimAdjusted = false;
  double _charge = 0;
  double _chargeHeld = 0;
  Vector2 _aimDir = Vector2(1, 0);
  Vector2? _moveStick;
  Vector2? _moveTarget;
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

  /// Right thumb, or a hold on the selected kid. Release throws.
  void pressThrowButton() {
    if (phase != MatchPhase.fight || _stickHolding) return;
    final kid = _readyThrower();
    if (kid == null) return;
    _stickHolding = true;
    _setSelected(kid);
    _beginCharge();
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
    _moveTarget = null;
    kid.setWalking(false);
    final stick = _moveStick;
    if (stick != null && stick.length >= 10) {
      _aimAdjusted = true;
      _aimDir = ThrowPhysics.clampAimDirection(stick, facingRight: true);
    } else if (!_aimAdjusted) {
      _aimAtNearest();
    }
    kid.showChargePose();
    _syncChargeHud();
    _publishCharge();
  }

  /// Left-stick deflection in screen space (y grows downward).
  /// While charging this aims; otherwise it walks one cell at a time.
  void setMoveStick(Offset deflection) {
    if (deflection.distance < 16) {
      _moveStick = null;
      return;
    }
    final dir = Vector2(deflection.dx, deflection.dy);
    _moveStick = dir;
    if (!_charging) return;
    _aimAdjusted = true;
    _aimDir = ThrowPhysics.clampAimDirection(dir, facingRight: true);
    _syncChargeHud();
  }

  void clearMoveStick() {
    _moveStick = null;
  }

  void releaseThrowButton() {
    if (!_stickHolding) return;
    _stickHolding = false;
    if (_yardHolding || !_charging) return;
    _releaseThrow();
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

  void _burst(Vector2 at) {
    world.add(ImpactBurst(sprite: _kit.impact, position: at.clone()));
  }

  void debugPointerDown(Vector2 point) => _onPointerDown(point);

  void debugPointerMove(Vector2 point) => _onPointerMove(point);

  void debugPointerUp() => _onPointerUp();

  void _onPointerDown(Vector2 point) {
    if (phase != MatchPhase.fight) return;
    _pointerDown = true;
    final selected = _selected;
    final onSelected =
        selected != null &&
        !selected.isKo &&
        point.distanceTo(selected.hitCenter) <= ArenaGrid.moveTouchRadius;
    if (!onSelected) {
      final tapped = _nearestLiving(
        players,
        point,
        maxDistance: ArenaGrid.moveTouchRadius,
      );
      if (tapped != null) _setSelected(tapped);
    }
    final kid = _selected;
    final grabbed =
        kid != null &&
        !kid.isKo &&
        !kid.isStunned &&
        point.distanceTo(kid.hitCenter) <= ArenaGrid.moveTouchRadius;
    if (grabbed) {
      _yardHolding = true;
      _beginCharge();
      return;
    }
    if (_charging) _applyAimAt(point);
  }

  void _onPointerMove(Vector2 point) {
    if (!_pointerDown || phase != MatchPhase.fight) return;
    if (_charging) _applyAimAt(point);
  }

  void _onPointerUp() {
    final yard = _yardHolding;
    _pointerDown = false;
    _yardHolding = false;
    if (yard && !_stickHolding && _charging) {
      _releaseThrow();
      return;
    }
    final kid = _selected;
    if (!_charging && kid != null && !kid.isKo && _moveTarget == null) {
      kid.setWalking(false);
    }
  }

  void _applyAimAt(Vector2 point) {
    final kid = _selected;
    if (kid == null) return;
    final dir = point - kid.throwOrigin;
    if (dir.length < 8) return;
    _aimAdjusted = true;
    _aimDir = ThrowPhysics.clampAimDirection(dir, facingRight: true);
    _syncChargeHud();
  }

  void _aimAtNearest() {
    final kid = _selected;
    if (kid == null) return;
    KidComponent? target;
    var best = double.infinity;
    for (final enemy in enemies) {
      if (enemy.isKo) continue;
      final distance = enemy.hitCenter.distanceToSquared(kid.throwOrigin);
      if (distance < best) {
        best = distance;
        target = enemy;
      }
    }
    final dir = target == null
        ? Vector2(1, 0)
        : target.hitCenter - kid.throwOrigin;
    _aimDir = ThrowPhysics.clampAimDirection(dir, facingRight: true);
  }

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
        kid.setWalking(false);
      }
      return;
    }
    if (_moveTarget == null) _tryStartStep(kid);
    _advanceStep(kid, dt);
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
    return true;
  }

  void _tryStartStep(KidComponent kid) {
    final dir = _activeMoveDir();
    if (dir == null) return;
    final step = _stepFrom(dir);
    if (step == null) return;
    final cell = ArenaGrid.nearestCell(KidSide.player, kid.position);
    final next = ArenaGrid.clampCell(
      cell.column + step.column,
      cell.row + step.row,
    );
    if (next.column == cell.column && next.row == cell.row) return;
    final dest = ArenaGrid.cellCenter(KidSide.player, next.column, next.row);
    if (dest.distanceTo(kid.position) < 1) return;
    _moveTarget = dest;
    kid.setWalking(true);
  }

  Vector2? _activeMoveDir() {
    final stick = _moveStick;
    if (stick != null && stick.length >= 16) return stick;
    return null;
  }

  /// One neighboring cell. Both axes can change, never by more than one.
  ({int column, int row})? _stepFrom(Vector2 dir) {
    if (dir.length2 < 1) return null;
    final length = dir.length;
    final nx = dir.x / length;
    final ny = dir.y / length;
    var column = 0;
    var row = 0;
    if (nx.abs() >= 0.38) column = nx > 0 ? 1 : -1;
    if (ny.abs() >= 0.38) row = ny > 0 ? 1 : -1;
    if (column == 0 && row == 0) {
      if (nx.abs() >= ny.abs()) {
        column = nx > 0 ? 1 : -1;
      } else {
        row = ny > 0 ? 1 : -1;
      }
    }
    return (column: column, row: row);
  }

  void _endActiveThrow() {
    _pointerDown = false;
    _yardHolding = false;
    _stickHolding = false;
    _charging = false;
    _charge = 0;
    _chargeHeld = 0;
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
