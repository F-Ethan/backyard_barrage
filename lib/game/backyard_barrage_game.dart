import 'dart:async';
import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../ads/ad_policy.dart';
import '../ads/end_ad.dart';
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
import 'components/coin_carry.dart';
import 'components/enemy_controller.dart';
import 'components/fort_component.dart';
import 'components/impact_burst.dart';
import 'components/kid_component.dart';
import 'components/lob_projectile.dart';
import 'components/overlay_banner.dart';
import 'throw_physics.dart';

enum MatchPhase { entering, fight, clearing, defeat, shop, paused }

enum _Banner { none, waveIntro, waveKo, waveDone, defeatKo, defeatCoins }

/// Landscape backyard arena: charge on the swivel, lob, then shop between waves.
class BackyardBarrageGame extends FlameGame {
  BackyardBarrageGame({
    required this.meta,
    SaveStore? saveStore,
    SettingsStore? settingsStore,
    FeelBus? feel,
    math.Random? random,
    this.onExitToMenu,
    this.endAd = const NoEndAd(),
    this.adsRemoved,
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
  final EndAd endAd;

  /// True once Remove Ads is owned. Read at the moment a run ends.
  final bool Function()? adsRemoved;
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

  /// Shop opened from the defeat screen. Closing it returns there.
  bool shoppingFromDefeat = false;

  /// Unspent coins at the moment the crew went down. The defeat beat shows
  /// this, and the wallet keeps the same amount.
  int carriedCoins = 0;

  /// Knockout coins earned during the current wave, before the clear bonus.
  int killCoinsThisWave = 0;

  final Set<KidComponent> _paidKills = {};

  /// Walk-on pace. Not the locked drag rate.
  static const double entranceSpeed = 280;

  static const double _offstage = 180;

  /// Seconds spent in the fight this run. Shop, pause, and banners do not
  /// count.
  double fightSeconds = 0;

  /// Wall clock for the interstitial cooldown. Tests replace this.
  @visibleForTesting
  DateTime Function() adClock = DateTime.now;

  DateTime? _lastAdShownAt;
  var _adInFlight = false;

  /// Right-hand share of the screen. A hold there charges; release throws.
  static const double chargeScreenFraction = 2 / 3;

  /// A touch this close to a kid's body selects them.
  static const double selectRadius = 72;

  /// Living kids stay at least this far apart while one is dragged.
  static const double kidSpacing = 64;

  bool _chargeHolding = false;

  /// Finger is down on the charge zone during the walk-on. The charge
  /// starts when the crews arrive, without a second press.
  bool _chargeArmed = false;
  final List<({KidComponent kid, Vector2 goal})> _entrance = [];
  CoinCarry? _coinCarry;
  Sprite? _coinSprite;
  bool _moveHolding = false;
  bool _charging = false;
  double _charge = 0;
  double _chargeHeld = 0;
  double _swivel = 0;
  Vector2 _aimDir = Vector2(1, 0);
  Vector2? _moveTarget;

  /// Feet minus the finger when the press landed on a kid, so a tap on the
  /// body does not slide them up onto the finger. Open ground uses zero.
  Vector2 _grabOffset = Vector2.zero();
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
    _coinSprite = await loadSprite('ui/coin_draft.png');

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
      size: ArenaGrid.fortDrawSize,
    );
    world.add(fort);
    enemyFort = FortComponent(
      side: KidSide.enemy,
      sprite: _fortIntact[1]!,
      position: ArenaGrid.fortAnchor(KidSide.enemy),
      size: ArenaGrid.fortDrawSize,
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
    if (phase != MatchPhase.fight &&
        phase != MatchPhase.clearing &&
        phase != MatchPhase.entering) {
      return;
    }
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
    if (wave <= 1) {
      fightSeconds = 0;
    }
    _pendingBanner = _Banner.none;
    _bannerTime = 0;
    _clearBanner();
    _clearCoinCarry();
    _endActiveThrow();
    _clearShots();
    _clearEnemies();
    _paidKills.clear();
    killCoinsThisWave = 0;
    phase = MatchPhase.entering;
    _entrance.clear();

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
      final goal = ArenaGrid.slot(KidSide.player, i);
      kid.revive();
      kid.shieldHits = meta.shieldCharges;
      kid.position = Vector2(-_offstage - i * 36, goal.y);
      kid.setWalking(true);
      kid.syncDepth();
      _entrance.add((kid: kid, goal: goal));
    }
    _setSelected(_firstLiving(players));
    _ensureAllyBrains();

    final count = CombatRules.enemyCountForWave(wave);
    for (var i = 0; i < count; i++) {
      final kid = _makeKid(KidSide.enemy, i);
      final goal = ArenaGrid.slot(KidSide.enemy, i);
      kid.position = Vector2(worldWidth + _offstage + i * 36, goal.y);
      kid.setWalking(true);
      kid.syncDepth();
      enemies.add(kid);
      world.add(kid);
      _entrance.add((kid: kid, goal: goal));
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
          playerChargeSeconds: _baseChargeSeconds,
        ),
      );
    }

    fort.applyStage(
      nextStage: meta.fortStage,
      intactSprite: _fortIntact[meta.fortStage]!,
      damagedSprite: _fortDamaged[meta.fortStage]!,
      collapsedSprite: _fortCollapsed!,
    );
    if (meta.fortBonusHp > 0) {
      fort.maxHp += meta.fortBonusHp;
      fort.hp = fort.maxHp;
    }
    enemyFort.applyStage(
      nextStage: 1,
      intactSprite: _fortIntact[1]!,
      damagedSprite: _fortDamaged[1]!,
      collapsedSprite: _fortCollapsed!,
    );
    fort.placeOnRow(ArenaGrid.rollFortRow(_rng));
    enemyFort.placeOnRow(ArenaGrid.rollFortRow(_rng));
    _showWaveIntro();
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
      maxHp: player ? CombatRules.hitsToKo : _tuning().enemyHitsToKo,
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
    if (shoppingFromDefeat) {
      closeSkillTree();
      return;
    }
    if (phase != MatchPhase.shop) return;
    if (overlays.isActive('shop')) overlays.remove('shop');
    if (paused) resumeEngine();
    wave += 1;
    startWave();
  }

  /// Skill tree between waves, or from the defeat screen before retry.
  void openSkillTree() {
    if (phase != MatchPhase.defeat && phase != MatchPhase.shop) return;
    shoppingFromDefeat = phase == MatchPhase.defeat;
    if (overlays.isActive('defeat')) overlays.remove('defeat');
    if (!overlays.isActive('shop')) overlays.add('shop');
  }

  /// Back to the defeat summary. Between waves this starts the next wave.
  void closeSkillTree() {
    if (!shoppingFromDefeat) {
      continueFromShop();
      return;
    }
    shoppingFromDefeat = false;
    if (overlays.isActive('shop')) overlays.remove('shop');
    if (phase == MatchPhase.defeat && !overlays.isActive('defeat')) {
      overlays.add('defeat');
    }
  }

  void retryFromDefeat() {
    if (overlays.isActive('defeat')) overlays.remove('defeat');
    if (paused) resumeEngine();
    wave = 1;
    startWave();
  }

  void exitToMenu() {
    _offerEndAd();
    overlays.clear();
    if (paused) resumeEngine();
    unawaited(persist());
    onExitToMenu?.call();
  }

  void resolveKnockouts() {
    if (phase != MatchPhase.fight) return;
    _payKnockouts();
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
    carriedCoins = meta.coins;
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
          subtitle: killCoinsThisWave > 0
              ? 'KO +$killCoinsThisWave · bonus +$lastReward'
              : '+$lastReward coins',
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
        _clearBanner();
        _showCoinCarry();
        _pendingBanner = _Banner.defeatCoins;
        _bannerTime = 1.45;
      case _Banner.defeatCoins:
        _pendingBanner = _Banner.none;
        _clearBanner();
        _clearCoinCarry();
        // After the coin beat, so the interstitial does not cover it.
        _offerEndAd();
        overlays.add('defeat');
        pauseEngine();
      case _Banner.waveIntro:
        _pendingBanner = _Banner.none;
        _clearBanner();
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

  /// Center title for the walk-on. Cleared when the crews reach their spots.
  void _showWaveIntro() {
    _showBanner('Wave $wave', fontSize: 56, color: const Color(0xFF1A2332));
    _pendingBanner = _Banner.waveIntro;
    _bannerTime = 0;
  }

  void _clearWaveIntro() {
    if (_pendingBanner != _Banner.waveIntro) return;
    _pendingBanner = _Banner.none;
    _bannerTime = 0;
    _clearBanner();
  }

  /// Label while the coin beat is on screen. Null before and after it.
  String? get coinCarryLabel => _coinCarry?.label;

  void _showCoinCarry() {
    _clearCoinCarry();
    final sprite = _coinSprite;
    if (sprite == null) return;
    _coinCarry = CoinCarry(
      sprite: sprite,
      amount: carriedCoins,
      position: Vector2(worldWidth / 2, worldHeight / 2 - 10),
    );
    world.add(_coinCarry!);
  }

  void _clearCoinCarry() {
    _coinCarry?.removeFromParent();
    _coinCarry = null;
  }

  /// Walk both crews from off-screen to their spots. Input stays locked.
  void _tickEntrance(double dt) {
    if (phase != MatchPhase.entering) return;
    var waiting = false;
    final step = entranceSpeed * dt;
    for (final mark in _entrance) {
      final kid = mark.kid;
      final delta = mark.goal - kid.position;
      final distance = delta.length;
      if (distance <= step || distance < 1) {
        kid.position = mark.goal.clone();
        kid.setWalking(false);
      } else {
        kid.position += delta / distance * step;
        kid.setWalking(true);
        waiting = true;
      }
      kid.syncDepth();
    }
    if (!waiting) {
      final held = _chargeArmed;
      _entrance.clear();
      _clearWaveIntro();
      phase = MatchPhase.fight;
      if (held) _beginHeldCharge();
    }
  }

  /// Skip the walk-on. Tests that start in a fight use this.
  @visibleForTesting
  void finishEntrance() {
    var guard = 0;
    while (phase == MatchPhase.entering && guard < 40) {
      update(0.25);
      guard += 1;
    }
  }

  DifficultyTuning _tuning() =>
      DifficultyTuning.of(feel.settings.difficulty, wave: wave);

  DifficultyTuning _allyTuning() {
    return DifficultyTuning.of(
      Difficulty.easy,
      wave: wave,
    ).scaled(gapScale: meta.allyGapScale, chargeScale: meta.allyChargeScale);
  }

  /// One interstitial outside the fight, at least three minutes after the
  /// last one that actually showed. Offered after the defeat coin beat,
  /// before the summary, and when Pause returns to the menu. A wave-clear
  /// shop does not offer one. Remove Ads skips it and does not start the
  /// cooldown.
  void _offerEndAd() {
    if (_adInFlight) return;
    if (adsRemoved?.call() ?? false) return;
    final now = adClock();
    final last = _lastAdShownAt;
    if (!AdPolicy.allows(
      inFight: phase == MatchPhase.fight,
      sinceLastShow: last == null ? null : now.difference(last),
    )) {
      return;
    }
    _adInFlight = true;
    unawaited(_finishAdOffer(now));
  }

  Future<void> _finishAdOffer(DateTime offeredAt) async {
    var shown = false;
    try {
      shown = await endAd.onRunEnded(fightSeconds: fightSeconds);
    } finally {
      _adInFlight = false;
      if (shown) _lastAdShownAt = offeredAt;
    }
  }

  void _payKnockouts() {
    var paid = 0;
    for (final kid in enemies) {
      if (!kid.isKo || !_paidKills.add(kid)) continue;
      paid += MetaState.coinsPerKnockout;
    }
    if (paid == 0) return;
    meta.coins += paid;
    killCoinsThisWave += paid;
  }

  /// Throw-rank hold before Easy or Normal shortens the player's bar.
  /// Bots scale from this, so their windup stays put when the bar speeds up.
  double _baseChargeSeconds() =>
      CombatRules.playerChargeSeconds(meta.throwRank);

  double _playerChargeSeconds() =>
      _baseChargeSeconds() * _tuning().playerChargeTimeScale;

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
          tuning: _allyTuning,
          initialDelay: profile.throwGap((0.35 + i * 0.2).clamp(0.0, 1.0)),
          onFire: _onAllyFire,
          isFighting: () => phase == MatchPhase.fight,
          side: KidSide.player,
          approachColumn: 1,
          isManual: () => identical(_selected, kid),
          currentWave: () => wave,
          playerChargeSeconds: _baseChargeSeconds,
          aimJitterScale: () => meta.allyAimScale,
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
  ///
  /// During the walk-on the finger is remembered and the charge starts
  /// when the crews reach their spots.
  void pressChargeZone() {
    if (phase == MatchPhase.entering) {
      _chargeArmed = true;
      return;
    }
    if (phase != MatchPhase.fight || _chargeHolding) return;
    _beginHeldCharge();
  }

  void _beginHeldCharge() {
    _chargeArmed = false;
    if (phase != MatchPhase.fight || _chargeHolding) return;
    final kid = _readyThrower();
    if (kid == null) return;
    _chargeHolding = true;
    _moveHolding = false;
    _moveTarget = null;
    _grabOffset = Vector2.zero();
    _setSelected(kid);
    _beginCharge();
  }

  void releaseChargeZone() {
    _chargeArmed = false;
    if (!_chargeHolding) return;
    _chargeHolding = false;
    if (_charging) _releaseThrow();
  }

  /// Left side of the screen. A touch selects a kid under the finger.
  /// While the finger stays down, the selected kid follows it.
  void pressMoveZone(Vector2 world) {
    if (phase != MatchPhase.fight || _charging) return;
    final tapped = _nearestLiving(players, world, maxDistance: selectRadius);
    if (tapped != null) _setSelected(tapped);
    final kid = _selected;
    if (kid == null || kid.isKo || kid.isStunned) return;
    _moveHolding = true;
    _moveTarget = world;
    // A finger on the body keeps the feet planted until the drag moves.
    _grabOffset = tapped != null && identical(tapped, kid)
        ? kid.position - world
        : Vector2.zero();
  }

  void dragMoveZone(Vector2 world) {
    if (!_moveHolding || _charging || phase != MatchPhase.fight) return;
    _moveTarget = world;
  }

  void releaseMoveZone() {
    _moveHolding = false;
    _moveTarget = null;
    _grabOffset = Vector2.zero();
    final kid = _selected;
    if (kid != null && !kid.isKo) kid.setWalking(false);
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
    _grabOffset = Vector2.zero();
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
      _playerChargeSeconds(),
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
    _spawnShot(owner: kid, lob: lob, targets: enemies, manualThrow: true);
  }

  void _spawnShot({
    required KidComponent owner,
    required RowLob lob,
    required List<KidComponent> targets,
    bool manualThrow = false,
  }) {
    final fromPlayer = owner.side == KidSide.player;
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
        passOwnFort: fromPlayer && meta.passesOwnFort,
        manualThrow: manualThrow,
        radius: fromPlayer
            ? MetaState.baseBlastRadius * meta.blastScale
            : MetaState.baseBlastRadius,
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
    applySnowballHit(shot: shot, target: target);
    feel.kidHit(knockedOut: target.isKo, season: meta.season);
    if (selectedHit) {
      _endActiveThrow();
      if (target.isKo || target.isStunned) {
        _setSelected(_firstReady(players) ?? _firstLiving(players));
      }
    }
    resolveKnockouts();
  }

  /// One snowball. Damage nodes repeat the hit. Shields eat a hit each time.
  @visibleForTesting
  void applySnowballHit({
    required LobProjectile shot,
    required KidComponent target,
  }) {
    if (phase != MatchPhase.fight || target.isKo) return;
    final owner = shot.owner;
    final fromPlayer = owner != null && owner.side == KidSide.player;
    final hits = fromPlayer ? meta.hitsFor(manualThrow: shot.manualThrow) : 1;
    final ally = target.side == KidSide.player;
    var scale = meta.stunScaleFor(ally: ally);
    // Difficulty shortens ally stun only. Rival brush-off and knockdown
    // stay the same length on Easy, Normal, and Hard.
    if (ally) scale *= _tuning().allyStunScale;
    for (var i = 0; i < hits && !target.isKo; i++) {
      target.takeHit(stunScale: scale);
    }
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
    if (kid.isStunned || _charging || !_moveHolding) {
      if (_moveTarget != null || _moveHolding) {
        _moveTarget = null;
        _grabOffset = Vector2.zero();
        _moveHolding = false;
        kid.setWalking(false);
      }
      return;
    }
    _dragKid(kid, dt);
  }

  /// Follows the finger inside the home half. Not snapped to a cell.
  void _dragKid(KidComponent kid, double dt) {
    final finger = _moveTarget;
    if (finger == null) return;
    final goal = _dragPoint(kid, finger + _grabOffset);
    // Locked drag rate. Difficulty does not speed this up or slow it down.
    final cap = ThrowPhysics.playerDragSpeed();
    final delta = goal - kid.position;
    final distance = delta.length;
    final step = cap * dt;
    if (distance <= step || distance < 0.8) {
      kid.position = goal.clone();
      kid.setWalking(distance > 0.8);
    } else {
      kid.position += delta / distance * step;
      kid.setWalking(true);
    }
    kid.syncDepth();
  }

  /// Feet stay in the player's half and off a teammate.
  Vector2 _dragPoint(KidComponent kid, Vector2 world) {
    final field = ArenaGrid.field(KidSide.player);
    var point = ArenaGrid.clampToRect(field, world);
    for (var pass = 0; pass < players.length; pass++) {
      for (final other in players) {
        if (identical(other, kid) || other.isKo) continue;
        point = _apartFrom(field, point, other.position);
      }
    }
    return point;
  }

  /// Pushes [point] out to [kidSpacing] from [other], staying inside [field].
  ///
  /// A teammate on the edge would otherwise clamp the push back on top of them.
  Vector2 _apartFrom(Rect field, Vector2 point, Vector2 other) {
    final away = point - other;
    final dist = away.length;
    if (dist >= kidSpacing) return point;
    final options = <Vector2>[
      if (dist >= 0.001) other + away / dist * kidSpacing,
      other + Vector2(kidSpacing, 0),
      other + Vector2(-kidSpacing, 0),
      other + Vector2(0, kidSpacing),
      other + Vector2(0, -kidSpacing),
    ];
    Vector2? best;
    var bestMiss = double.infinity;
    for (final option in options) {
      final clamped = ArenaGrid.clampToRect(field, option);
      if (clamped.distanceTo(other) < kidSpacing - 0.5) continue;
      final miss = clamped.distanceTo(point);
      if (miss < bestMiss) {
        bestMiss = miss;
        best = clamped;
      }
    }
    return best ?? point;
  }

  void _endActiveThrow() {
    _chargeHolding = false;
    _chargeArmed = false;
    _moveHolding = false;
    _charging = false;
    _charge = 0;
    _chargeHeld = 0;
    _swivel = 0;
    _moveTarget = null;
    _grabOffset = Vector2.zero();
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
    _tickEntrance(dt);
    if (phase == MatchPhase.fight) fightSeconds += dt;
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
          _playerChargeSeconds(),
        );
        _swivel = ThrowPhysics.swivelElevation(_chargeHeld);
        _aimDir = ThrowPhysics.aimForElevation(_swivel, facingRight: true);
        kid.showChargeYaw(ThrowPhysics.chargeYaw(_swivel));
        _syncChargeHud();
        _publishCharge();
      }
    }
    // The wave title stays up for the whole walk-on, then _tickEntrance
    // clears it. Other banners still run on a timer.
    if (_pendingBanner != _Banner.none && _pendingBanner != _Banner.waveIntro) {
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
