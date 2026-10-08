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
import '../meta/power_up.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/arena.dart';
import '../seasons/season.dart';
import '../seasons/season_kit.dart';
import 'arena_grid.dart';
import 'combat_rules.dart';
import 'crew_carry.dart';
import 'rival_type.dart';
import 'components/charge_indicator.dart';
import 'components/coin_pop.dart';
import 'components/coin_carry.dart';
import 'components/enemy_controller.dart';
import 'components/fort_component.dart';
import 'components/hound_component.dart';
import 'components/impact_burst.dart';
import 'components/kid_component.dart';
import 'components/lob_projectile.dart';
import 'components/overlay_banner.dart';
import 'components/splash_particles.dart';
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
  final Map<KidComponent, RivalType> _rivalTypes = {};

  /// What kind of rival [kid] is. Player kids and unknowns read as ghosts.
  RivalType rivalTypeOf(KidComponent kid) =>
      _rivalTypes[kid] ?? RivalType.snowGhost;

  late FortComponent fort;
  late FortComponent enemyFort;
  late ChargeIndicator chargeHud;
  late SeasonKit _kit;
  late SpriteComponent _bg;
  final Map<Arena, Sprite> _arenaArt = {};
  Arena _arena = Arena.backyard;

  /// The map this run is played on. Rolled when a run starts.
  Arena get arena => _arena;

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

  /// Pan angle in radians, and which way it is moving (+1 up-screen). It
  /// bounces between [ThrowPhysics.sweepLimits].
  double _sweepElev = 0;
  double _sweepDir = 1;

  /// Sweep speed as a share of full speed. Eases toward the friction share
  /// while the line is on a rival, and back to 1 off it.
  double _sweepSpeed = 1;
  KidComponent? _aimTarget;
  Vector2 _aimDir = Vector2(1, 0);
  Vector2? _moveTarget;

  /// Feet minus the finger when the press landed on a kid, so a tap on the
  /// body does not slide them up onto the finger. Open ground uses zero.
  Vector2 _grabOffset = Vector2.zero();
  _Banner _pendingBanner = _Banner.none;
  double _bannerTime = 0;

  /// Center banner for the Flutter HUD (`lib/ui/match_banner.dart`).
  final ValueNotifier<BannerSpec?> bannerListenable = ValueNotifier(null);
  KidComponent? _selected;

  /// Hit-stop: the yard freezes for this long after a hit lands.
  double _hitStop = 0;
  double _shakeTime = 0;
  double _shakeTotal = 0;
  double _shakeMagnitude = 0;

  /// Hit-stop and screen shake lengths. KO lands a little heavier.
  static const double hitStopSeconds = 0.06;
  static const double koStopSeconds = 0.11;
  static const double hitShakePx = 5;
  static const double koShakePx = 9;
  static const double shakeSeconds = 0.18;

  /// OS "reduce motion" turns off hit-stop and shake. Tests can override.
  @visibleForTesting
  bool Function() reduceMotion = () {
    final a11y = PlatformDispatcher.instance.accessibilityFeatures;
    return a11y.disableAnimations || a11y.reduceMotion;
  };

  double get charge => _charge;

  bool get isCharging => _charging;

  KidComponent? get selectedKid => _selected;

  // Power-ups waiting on the next throw, and Frost armor time left.
  bool _crackerArmed = false;
  bool _splatArmed = false;
  bool _powerArmed = false;
  double _armorTime = 0;

  /// True while that power-up is armed for the next throw (or Frost armor
  /// is up). The HUD lights its button.
  bool isPowerUpLive(PowerUp item) => switch (item) {
    PowerUp.frostArmor => _armorTime > 0,
    PowerUp.fortCracker => _crackerArmed,
    PowerUp.bigSplat => _splatArmed,
    PowerUp.powerThrow => _powerArmed,
    PowerUp.freezeAll || PowerUp.hotCocoa => false,
  };

  /// Fire one [item] from the wallet. False outside a live fight, when the
  /// wallet has none, or when that item is already armed.
  bool usePowerUp(PowerUp item) {
    if (phase != MatchPhase.fight) return false;
    if (isPowerUpLive(item)) return false;
    if (item == PowerUp.hotCocoa &&
        !players.any((kid) => !kid.isKo && kid.hp < kid.maxHp)) {
      return false; // nobody to heal; keep the cocoa
    }
    if (!meta.useItem(item)) return false;
    switch (item) {
      case PowerUp.frostArmor:
        _armorTime = PowerUp.armorSeconds;
        for (final kid in players) {
          kid.armored = !kid.isKo;
        }
      case PowerUp.fortCracker:
        _crackerArmed = true;
      case PowerUp.freezeAll:
        for (final rival in enemies) {
          rival.freeze(PowerUp.freezeSeconds);
        }
      case PowerUp.powerThrow:
        _powerArmed = true;
      case PowerUp.bigSplat:
        _splatArmed = true;
      case PowerUp.hotCocoa:
        for (final kid in players) {
          if (!kid.isKo) {
            kid.hp = math.min(kid.hp + 1, kid.maxHp);
          }
        }
    }
    feel.powerUpUsed(item);
    hudRevision.value++;
    unawaited(persist());
    return true;
  }

  void _clearPowerUps() {
    _crackerArmed = false;
    _splatArmed = false;
    _powerArmed = false;
    _armorTime = 0;
    for (final kid in players) {
      kid.armored = false;
    }
  }

  /// The rival the current charge would hit if released now. Null when the
  /// line misses or falls short.
  KidComponent? get aimTarget => _aimTarget;

  @override
  Color backgroundColor() =>
      meta.season == Season.summer ? const Color(0xFF87CEEB) : _arena.sky;

  /// Winter plays on the run's [arena]. Summer keeps its own yard art.
  Sprite _backdrop(SeasonKit kit) {
    if (kit.season == Season.winter) {
      final art = _arenaArt[_arena];
      if (art != null) return art;
    }
    return kit.background;
  }

  @visibleForTesting
  void debugUseArena(Arena arena) {
    _arena = arena;
    if (isLoaded) _bg.sprite = _backdrop(_kit);
  }

  /// A new map for a new run, different from the last one when possible.
  void _rollArena({bool avoidCurrent = false}) {
    _arena = Arena.pick(_rng, except: avoidCurrent ? _arena : null);
    if (isLoaded) _bg.sprite = _backdrop(_kit);
  }

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
    Future<Sprite> hound(String frame) {
      final path = HoundComponent.framePath(frame);
      final crop = SeasonAssets.crop(path)!;
      return loadSprite(
        path,
        srcPosition: Vector2(crop.$1, crop.$2),
        srcSize: Vector2.all(crop.$3),
      );
    }

    _houndSprites = HoundSprites(
      idle: await hound('idle'),
      run: [
        for (final i in ['00', '01', '02', '03']) await hound('run_$i'),
      ],
      crouch: await hound('jump_00'),
      leap: await hound('jump_01'),
      bite: [await hound('bite_00'), await hound('bite_01')],
    );
    for (final arena in Arena.values) {
      _arenaArt[arena] = await loadSprite(arena.background);
    }
    _arena = Arena.pick(_rng);
    _takeResume();

    _bg = SpriteComponent(
      sprite: _backdrop(_kit),
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
    if (meta.season == season || !Season.playable.contains(season)) return;
    meta.season = season;
    final kit = _kits[season];
    if (kit != null && isLoaded) _applyKit(kit);
    await persist();
    await feel.enterBattle(season);
  }

  void _applyKit(SeasonKit kit) {
    _kit = kit;
    _bg.sprite = _backdrop(kit);
    for (final kid in players) {
      kid.applyPoses(kit.playerPoses);
    }
    for (final kid in enemies) {
      kid.applyPoses(kit.posesFor(rivalTypeOf(kid)));
    }
  }

  void startWave() {
    if (wave <= 1) {
      fightSeconds = 0;
    }
    _settling = false;
    _settleTime = 0;
    _pendingBanner = _Banner.none;
    _bannerTime = 0;
    _clearBanner();
    _clearCoinCarry();
    _endActiveThrow();
    _clearPowerUps();
    _rollHound();
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
    final crewHp = _nextCrewHp();
    _waveStartHp = List<int>.of(crewHp);
    for (var i = 0; i < players.length; i++) {
      final kid = players[i];
      final goal = ArenaGrid.slot(KidSide.player, i);
      if (crewHp[i] <= 0) {
        // Knocked out in an earlier wave and not brought back.
        kid.benchOut();
        kid.position = Vector2(-_offstage - i * 36, goal.y);
        continue;
      }
      kid.revive();
      kid.hp = crewHp[i];
      kid.shieldHits = meta.shieldCharges;
      kid.position = Vector2(-_offstage - i * 36, goal.y);
      kid.setWalking(true);
      kid.syncDepth();
      _entrance.add((kid: kid, goal: goal));
    }
    _setSelected(_firstLiving(players));
    _ensureAllyBrains();

    final count = CombatRules.enemyCountForWave(wave);
    final lineup = RivalRoster.forWave(count: count, rng: _rng);
    for (var i = 0; i < count; i++) {
      final type = lineup[i];
      final rival = RivalProfile.of(type);
      final kid = _makeRival(type, i);
      final slot =
          ArenaGrid.enemySlots[i.clamp(0, ArenaGrid.enemySlots.length - 1)];
      // Slot rows are distinct, so a type's home column never stacks kids.
      final goal = ArenaGrid.cellCenter(
        KidSide.enemy,
        rival.holdColumn ?? slot.$1,
        slot.$2,
      );
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
          isFighting: () => phase == MatchPhase.fight && !_settling,
          playerChargeSeconds: _baseChargeSeconds,
          profile: rival,
          onWindup: rival.glint ? feel.frostGlint : null,
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

  KidComponent _makeRival(RivalType type, int slot) {
    final kid = KidComponent(
      side: KidSide.enemy,
      poses: _kit.posesFor(type),
      position: ArenaGrid.slot(KidSide.enemy, slot),
      size: Vector2.all(ArenaGrid.kidSize),
      maxHp: RivalProfile.of(type).hitsToKo(_tuning().enemyHitsToKo),
    );
    final profile = RivalProfile.of(type);
    kid.glint = profile.glint;
    kid.aura = profile.aura;
    final at = profile.glintAt;
    if (at != null) kid.glintAt = Vector2(at.$1, at.$2);
    _rivalTypes[kid] = type;
    return kid;
  }

  void _clearEnemies() {
    for (final enemy in List<KidComponent>.of(enemies)) {
      enemy.removeFromParent();
    }
    enemies.clear();
    _rivalTypes.clear();
  }

  // Ice hound: rolled at wave start, released partway into the fight.
  HoundSprites? _houndSprites;
  HoundComponent? _hound;
  double? _houndAt;
  double _waveFight = 0;

  /// The hound on the yard, if any.
  HoundComponent? get hound => _hound;

  /// Seconds into the fight when this wave's hound comes, or null.
  double? get houndDueAt => _houndAt;

  void _rollHound() {
    _clearHound();
    _waveFight = 0;
    final difficulty = feel.settings.difficulty;
    _houndAt =
        wave >= HoundComponent.firstWave &&
            _rng.nextDouble() < HoundComponent.chanceFor(difficulty)
        ? 4 + _rng.nextDouble() * 5
        : null;
  }

  void _clearHound() {
    _hound?.removeFromParent();
    _hound = null;
  }

  /// Sends the hound down [target]'s lane now.
  @visibleForTesting
  HoundComponent releaseHound(KidComponent target) {
    _clearHound();
    _houndAt = null;
    final hound = HoundComponent(
      sprites: _houndSprites!,
      laneY: target.position.y,
      players: players,
      onCatch: _houndCaught,
      isLive: () => phase == MatchPhase.fight,
      difficulty: feel.settings.difficulty,
      onState: _houndSound,
    );
    _hound = hound;
    world.add(hound);
    feel.houndGrowl();
    return hound;
  }

  void _houndSound(HoundState state) {
    switch (state) {
      case HoundState.jump:
        feel.houndLeap();
      case HoundState.flee:
        feel.houndWhimper();
      default:
        break;
    }
  }

  void _tickHound(double dt) {
    if (phase != MatchPhase.fight) return;
    _waveFight += dt;
    final due = _houndAt;
    if (due != null && !_settling && _waveFight >= due) {
      final living = [
        for (final kid in players)
          if (!kid.isKo) kid,
      ];
      _houndAt = null;
      if (living.isNotEmpty) {
        releaseHound(living[_rng.nextInt(living.length)]);
      }
    }
    // A player snowball that meets the hound before it crosses scares it.
    final hound = _hound;
    if (hound == null || !hound.scareable) return;
    for (final shot in world.children.whereType<LobProjectile>()) {
      if (shot.spent || shot.owner?.side != KidSide.player) continue;
      if (!ThrowPhysics.snowballContacts(
        ground: shot.hitPosition,
        shotRadius: shot.radius,
        kidCenter: hound.hitCenter,
        kidRadius: HoundComponent.hitRadius,
      )) {
        continue;
      }
      _burst(shot.position, power: 0.8);
      shot.absorb();
      hound.scare();
      return;
    }
  }

  /// The hound's bite: a one-hit knockout on every difficulty. Frost armor
  /// is the only thing that turns it away.
  bool _houndCaught(KidComponent kid) {
    if (phase != MatchPhase.fight || kid.isKo) return false;
    if (_armorTime > 0) {
      feel.armorBlocked();
      return false;
    }
    final selected = identical(kid, _selected);
    kid.knockOutNow();
    feel.houndSnap();
    _burst(kid.hitCenter, depthY: kid.hitCenter.y, power: 1.3);
    feel.kidHit(knockedOut: true, season: meta.season);
    _punch(knockedOut: true);
    if (selected) {
      _endActiveThrow();
      _setSelected(_firstReady(players) ?? _firstLiving(players));
    }
    resolveKnockouts();
    return true;
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
    _rollArena(avoidCurrent: true);
    startWave();
  }

  /// HP each player kid starts the wave on. A resumed run uses its saved
  /// crew; the first wave of a run starts full; later waves carry per
  /// [CrewCarry]. A kid bought in the shop joins at full health.
  List<int> _nextCrewHp() {
    final maxHp = CombatRules.hitsToKo;
    final saved = _resumeCrewHp;
    _resumeCrewHp = null;
    if (saved != null) {
      return [
        for (var i = 0; i < players.length; i++)
          i < saved.length ? saved[i].clamp(0, maxHp) : maxHp,
      ];
    }
    if (wave <= 1) return List.filled(players.length, maxHp);
    return _carriedHp([for (final kid in players) kid.hp]);
  }

  List<int> _carriedHp(List<int> now) => CrewCarry.next(
    hp: now,
    maxHp: CombatRules.hitsToKo,
    difficulty: feel.settings.difficulty,
    carries: true,
    healBonus: meta.healPerWave,
    reviveOne: meta.reviveOne,
  );

  List<int>? _resumeCrewHp;
  List<int> _waveStartHp = const [];

  /// Picks up a run left through Pause → Menu: same wave (the next one if
  /// that wave was already cleared), same arena, and in Campaign the saved
  /// crew health. The bookmark is used once.
  void _takeResume() {
    if (!meta.canResume) return;
    wave = meta.resumeWave;
    _resumeCrewHp = meta.resumeCrewHp;
    meta.resumeCrewHp = null;
    for (final arena in Arena.values) {
      if (arena.name == meta.resumeArena) _arena = arena;
    }
    meta.resumeWave = 0;
    meta.resumeArena = null;
  }

  /// Bookmark the run when leaving mid-run (not after a defeat).
  void _bookmarkRun() {
    final at = phase == MatchPhase.paused ? _resumePhase : phase;
    switch (at) {
      case MatchPhase.entering || MatchPhase.fight:
        // Replay this wave with the health it started on.
        meta.resumeWave = wave;
        meta.resumeCrewHp = List<int>.of(_waveStartHp);
      case MatchPhase.clearing || MatchPhase.shop:
        // This wave already paid out; pick up on the next one, with the
        // health the crew would carry into it.
        meta.resumeWave = wave + 1;
        meta.resumeCrewHp = _carriedHp([for (final kid in players) kid.hp]);
      case MatchPhase.defeat || MatchPhase.paused:
        meta.resumeWave = 0;
        meta.resumeCrewHp = null;
    }
    meta.resumeArena = meta.resumeWave > 0 ? _arena.name : null;
  }

  void exitToMenu() {
    _bookmarkRun();
    _offerEndAd();
    overlays.clear();
    if (paused) resumeEngine();
    unawaited(persist());
    onExitToMenu?.call();
  }

  /// A side is down but snowballs are still in the air. The fight holds
  /// until they land (their hits still count), then the result is called.
  /// Nobody starts a new throw meanwhile.
  bool _settling = false;
  double _settleTime = 0;

  /// Longest the result waits on in-flight shots.
  static const double settleCapSeconds = 4;

  @visibleForTesting
  bool get settling => _settling;

  bool get _shotsInFlight => world.children.whereType<LobProjectile>().any(
    (shot) => !shot.spent && !shot.isRemoving,
  );

  void resolveKnockouts() {
    if (phase != MatchPhase.fight) return;
    _payKnockouts();
    final livingPlayers = players.where((kid) => !kid.isKo).length;
    final livingEnemies = enemies.where((kid) => !kid.isKo).length;
    final outcome = CombatRules.roundOutcome(
      livingPlayers: livingPlayers,
      livingEnemies: livingEnemies,
    );
    if (outcome != RoundOutcome.ongoing &&
        _shotsInFlight &&
        _settleTime < settleCapSeconds) {
      if (!_settling) {
        _settling = true;
        _settleTime = 0;
        _endActiveThrow();
      }
      return;
    }
    _settling = false;
    _settleTime = 0;
    switch (outcome) {
      case RoundOutcome.defeat:
        _beginDefeat();
      case RoundOutcome.waveClear:
        _beginWaveClear();
      case RoundOutcome.ongoing:
        break;
    }
  }

  void _beginWaveClear() {
    _clearHound();
    _houndAt = null;
    if (phase != MatchPhase.fight) return;
    phase = MatchPhase.clearing;
    _endActiveThrow();
    _clearShots();
    lastReward = MetaState.coinsForWave(wave);
    meta.earn(lastReward);
    meta.noteWaveCleared(wave);
    unawaited(persist());
    feel.waveCleared();
    _showBanner('KO!', fontSize: 56, color: const Color(0xFFFFE66D));
    _pendingBanner = _Banner.waveKo;
    _bannerTime = 0.65;
  }

  void _beginDefeat() {
    _clearHound();
    _houndAt = null;
    if (phase == MatchPhase.defeat || phase == MatchPhase.shop) return;
    phase = MatchPhase.defeat;
    _endActiveThrow();
    _clearShots();
    feel.defeated();
    carriedCoins = meta.coins;
    meta.resetRun();
    meta.resumeWave = 0;
    meta.resumeArena = null;
    meta.resumeCrewHp = null;
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
    bannerListenable.value = BannerSpec(
      label: label,
      subtitle: subtitle,
      fontSize: fontSize,
      color: color,
    );
  }

  void _clearBanner() {
    bannerListenable.value = null;
  }

  /// Center title for the walk-on. Cleared when the crews reach their spots.
  void _showWaveIntro() {
    _showBanner('Wave $wave', fontSize: 56, color: const Color(0xFF1A2332));
    feel.waveStart();
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

  DifficultyTuning _tuning() => DifficultyTuning.of(
    feel.settings.difficulty,
    wave: wave,
    rivalCurve: true,
  );

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
    meta.earn(paid);
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
    double rangeScale, {
    Vector2? aimAt,
  }) {
    if (phase != MatchPhase.fight || enemy.isKo) return;
    feel.enemyReleased();
    final cell = ArenaGrid.nearestCell(KidSide.enemy, enemy.position);
    final targetRow = target == null
        ? cell.row
        : ArenaGrid.nearestCell(target.side, target.position).row;
    final point = aimAt ?? target?.hitCenter;
    final distance = point == null
        ? 640.0
        : (enemy.throwOrigin.x - point.x).abs();
    final lob = ThrowPhysics.planEnemyLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      targetRow: targetRow,
      distance: distance,
      rangeScale: rangeScale,
      facingRight: false,
      originY: enemy.throwOrigin.y,
      trackY: enemy.hitCenter.y,
      targetY: point?.y,
    );
    _spawnShot(owner: enemy, lob: lob, targets: players);
  }

  void _onAllyFire(
    KidComponent ally,
    KidComponent? target,
    double rangeScale, {
    Vector2? aimAt,
  }) {
    if (phase != MatchPhase.fight || ally.isKo || identical(ally, _selected)) {
      return;
    }
    feel.playerReleased();
    final cell = ArenaGrid.nearestCell(KidSide.player, ally.position);
    final targetRow = target == null
        ? cell.row
        : ArenaGrid.nearestCell(target.side, target.position).row;
    final point = aimAt ?? target?.hitCenter;
    final distance = point == null
        ? 640.0
        : (ally.throwOrigin.x - point.x).abs();
    final lob = ThrowPhysics.planEnemyLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      targetRow: targetRow,
      distance: distance,
      rangeScale: rangeScale,
      facingRight: true,
      originY: ally.throwOrigin.y,
      trackY: ally.hitCenter.y,
      targetY: point?.y,
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
          isFighting: () => phase == MatchPhase.fight && !_settling,
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
    if (phase != MatchPhase.fight || _chargeHolding || _settling) return;
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
    feel.chargeHum(true);
    _chargeHeld = 0;
    _charge = ThrowPhysics.minThrowCharge;
    if (_powerArmed) {
      // Power throw: the bar starts full. It stays armed until the throw
      // leaves the hand, so a cancelled charge does not waste it.
      _chargeHeld = _playerChargeSeconds();
      _charge = 1;
    }
    _swivel = 0;
    _sweepElev = 0;
    _sweepDir = 1;
    _sweepSpeed = 1;
    _aimTarget = null;
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
    feel.chargeHum(false);
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
    final elevation = _assistedElevation(
      kid,
      ThrowPhysics.aimElevation(_aimDir, facingRight: true),
      ThrowPhysics.rangeForCharge(charge),
    );
    _aimTarget = null;
    final lob = ThrowPhysics.planPlayerLob(
      throwerRow: cell.row,
      throwerColumn: cell.column,
      aimDirection: ThrowPhysics.aimForElevation(elevation, facingRight: true),
      charge: charge,
      facingRight: true,
      speedScale: CombatRules.projectileSpeedScale(meta.throwRank),
      originY: kid.throwOrigin.y,
      trackY: kid.hitCenter.y,
    );
    kid.showThrowPose();
    feel.playerReleased(fullPower: charge >= 0.999);
    _spawnShot(owner: kid, lob: lob, targets: enemies, manualThrow: true);
  }

  void _spawnShot({
    required KidComponent owner,
    required RowLob lob,
    required List<KidComponent> targets,
    bool manualThrow = false,
  }) {
    final fromPlayer = owner.side == KidSide.player;
    final shot = LobProjectile(
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
          ? MetaState.baseBlastRadius *
                meta.blastScale *
                (manualThrow && _splatArmed ? PowerUp.splatScale : 1)
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
      trackY: lob.trackY,
      onHit: _onKidHit,
      onFortHit: _onFortHit,
      onGround: _onGroundMiss,
    );
    if (manualThrow && fromPlayer) {
      shot.cracker = _crackerArmed;
      _crackerArmed = false;
      _splatArmed = false;
      _powerArmed = false;
      hudRevision.value++;
    }
    world.add(shot);
  }

  @visibleForTesting
  void debugKidHit(LobProjectile shot, KidComponent target) =>
      _onKidHit(shot, target);

  void _onKidHit(LobProjectile shot, KidComponent target) {
    _burst(shot.position, depthY: target.hitCenter.y);
    if (phase != MatchPhase.fight || target.isKo) return;
    final selectedHit = identical(target, _selected);
    if (!applySnowballHit(shot: shot, target: target)) {
      feel.armorBlocked();
      return;
    }
    feel.kidHit(knockedOut: target.isKo, season: meta.season);
    target.recoil(shot.facing);
    _punch(knockedOut: target.isKo);
    if (target.isKo && target.side == KidSide.enemy) {
      world.add(
        CoinPop(
          amount: MetaState.coinsPerKnockout,
          position: target.hitCenter - Vector2(0, 92),
        ),
      );
      feel.coinPop();
    }
    if (selectedHit) {
      _endActiveThrow();
      if (target.isKo || target.isStunned) {
        _setSelected(_firstReady(players) ?? _firstLiving(players));
      }
    }
    resolveKnockouts();
  }

  /// One snowball. Damage nodes repeat the hit. Shields eat a hit each time.
  /// False when Frost armor turned it away.
  @visibleForTesting
  bool applySnowballHit({
    required LobProjectile shot,
    required KidComponent target,
  }) {
    if (phase != MatchPhase.fight || target.isKo) return true;
    final owner = shot.owner;
    final fromPlayer = owner != null && owner.side == KidSide.player;
    final ally = target.side == KidSide.player;
    if (ally && _armorTime > 0) return false; // Frost armor
    final hits = fromPlayer ? meta.hitsFor(manualThrow: shot.manualThrow) : 1;
    var scale = meta.stunScaleFor(ally: ally);
    // Difficulty shortens ally stun only. Rival brush-off and knockdown
    // stay the same length on Easy, Normal, and Hard.
    if (ally) scale *= _tuning().allyStunScale;
    for (var i = 0; i < hits && !target.isKo; i++) {
      target.takeHit(stunScale: scale);
    }
    return true;
  }

  @visibleForTesting
  void debugFortHit(LobProjectile shot) => _onFortHit(shot);

  void _onFortHit(LobProjectile shot) {
    _burst(shot.position, power: 0.75);
    final cover = shot.struckFort;
    if (phase != MatchPhase.fight || cover == null) {
      feel.impact(meta.season);
      return;
    }
    if (shot.cracker && cover.side == KidSide.enemy) {
      cover.collapse();
      // A whole fort coming down lands harder than a chip.
      _burst(shot.position, power: 1.6);
      _punch(knockedOut: true);
      feel.fortCollapsed();
      return;
    }
    final wasStanding = cover.standing;
    if (shot.fortDamage) cover.takeHit();
    if (wasStanding && cover.isCollapsed) {
      feel.fortCollapsed();
    } else {
      feel.fortHit();
    }
  }

  void _onGroundMiss(LobProjectile shot) {
    _burst(shot.position, power: 0.6);
    feel.impact(meta.season);
  }

  void _burst(Vector2 at, {double? depthY, double power = 1}) {
    world.add(
      ImpactBurst(sprite: _kit.impact, position: at.clone(), depthY: depthY),
    );
    world.add(
      SplashParticles(
        position: at.clone(),
        season: meta.season,
        rng: _rng,
        depthY: depthY,
        count: (12 * power).round(),
        power: power,
      ),
    );
  }

  /// Hit-stop and a short shake. Skipped under OS reduce-motion.
  void _punch({required bool knockedOut}) {
    if (reduceMotion()) return;
    _hitStop = math.max(_hitStop, knockedOut ? koStopSeconds : hitStopSeconds);
    _shakeMagnitude = math.max(
      _shakeTime > 0 ? _shakeMagnitude : 0,
      knockedOut ? koShakePx : hitShakePx,
    );
    _shakeTime = shakeSeconds;
    _shakeTotal = shakeSeconds;
  }

  @visibleForTesting
  double get hitStopRemaining => _hitStop;

  @override
  void updateTree(double dt) {
    _tickShake(dt);
    if (_hitStop > 0 && !paused) {
      _hitStop -= dt;
      // Lifecycle still runs; nothing in the yard moves.
      super.updateTree(0);
      return;
    }
    super.updateTree(dt);
  }

  void _tickShake(double dt) {
    final view = camera.viewfinder;
    if (_shakeTime <= 0) {
      if (!view.position.isZero()) view.position = Vector2.zero();
      return;
    }
    _shakeTime -= dt;
    final fall = (_shakeTime / _shakeTotal).clamp(0.0, 1.0);
    final m = _shakeMagnitude * fall;
    view.position = Vector2(
      (_rng.nextDouble() * 2 - 1) * m,
      (_rng.nextDouble() * 2 - 1) * m,
    );
  }

  /// Moves the pan and bounces it off the limits for this kid's spot. The
  /// overshoot reflects, so the turn is instant rather than a pause.
  void _stepPan(KidComponent kid, double dt) {
    final (low, high) = ThrowPhysics.sweepLimits(_trackStart(kid));
    if (high - low < 1e-3) {
      _sweepElev = 0;
      return;
    }
    var next =
        _sweepElev + _sweepDir * ThrowPhysics.sweepSpeed * _sweepSpeed * dt;
    if (next > high) {
      next = high - (next - high);
      _sweepDir = -1;
    } else if (next < low) {
      next = low + (low - next);
      _sweepDir = 1;
    }
    _sweepElev = next.clamp(low, high);
  }

  /// Where the selected kid's track starts: in front of the hand, at body
  /// height.
  Vector2 _trackStart(KidComponent kid) =>
      Vector2(kid.throwOrigin.x, kid.hitCenter.y);

  /// The nearest rival the line at [elevation] would hit within [range],
  /// and the smallest depth miss to any reachable rival.
  ({KidComponent? hit, KidComponent? near, double nearMiss}) _scanAim(
    KidComponent kid,
    double elevation,
    double range,
  ) {
    final start = _trackStart(kid);
    final window = ArenaGrid.rowStep * ThrowPhysics.depthWindowFraction;
    KidComponent? hit;
    var hitForward = double.infinity;
    KidComponent? near;
    var nearMiss = double.infinity;
    for (final rival in enemies) {
      if (rival.isKo) continue;
      final miss = ThrowPhysics.trackMiss(
        start: start,
        elevation: elevation,
        range: range,
        facingRight: true,
        target: rival.hitCenter,
        reachSlop: rival.hitRadius,
      );
      if (miss == null) continue;
      final forward = rival.hitCenter.x - start.x;
      if (miss.abs() <= window && forward < hitForward) {
        hit = rival;
        hitForward = forward;
      }
      if (miss.abs() < nearMiss) {
        nearMiss = miss.abs();
        near = rival;
      }
    }
    return (hit: hit, near: near, nearMiss: nearMiss);
  }

  @visibleForTesting
  double assistedElevation(KidComponent kid, double elevation, double range) =>
      _assistedElevation(kid, elevation, range);

  /// Release assist: a line that just misses a reachable rival is nudged
  /// onto them. A clear miss stays a miss.
  double _assistedElevation(KidComponent kid, double elevation, double range) {
    final scan = _scanAim(kid, elevation, range);
    if (scan.hit != null) return elevation;
    final near = scan.near;
    final window = ArenaGrid.rowStep * ThrowPhysics.depthWindowFraction;
    if (near == null || scan.nearMiss > window + ThrowPhysics.aimAssistPx) {
      return elevation;
    }
    return ThrowPhysics.elevationToward(
      start: _trackStart(kid),
      target: near.hitCenter,
      facingRight: true,
    );
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
    final start = _trackStart(kid);
    final range = ThrowPhysics.rangeForCharge(_charge);
    final elevation = ThrowPhysics.aimElevation(_aimDir, facingRight: true);
    final edge = ThrowPhysics.yardFarEdge - start.x;
    Vector2 along(double forward) => Vector2(
      start.x + forward,
      ThrowPhysics.clampTrackY(
        ThrowPhysics.trackYAt(
          startY: start.y,
          elevation: elevation,
          forward: forward,
        ),
      ),
    );
    final preview = feel.settings.difficulty.aimPreview;
    chargeHud.showPath = preview != AimPreview.none;
    chargeHud.trackStart = start;
    chargeHud.trackEnd = along(math.min(range, edge));
    chargeHud.range = range;
    chargeHud.target = preview == AimPreview.full
        ? _aimTarget?.hitCenter
        : null;
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

  /// Feet stay in the player's half, short of the river, and off a teammate.
  Vector2 _dragPoint(KidComponent kid, Vector2 world) {
    var point = ArenaGrid.clampPlayerFeet(world);
    for (var pass = 0; pass < players.length; pass++) {
      for (final other in players) {
        if (identical(other, kid) || other.isKo) continue;
        point = _apartFrom(point, other.position);
      }
    }
    return point;
  }

  /// Pushes [point] out to [kidSpacing] from [other], staying walkable.
  ///
  /// A teammate on the edge would otherwise clamp the push back on top of them.
  Vector2 _apartFrom(Vector2 point, Vector2 other) {
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
      final clamped = ArenaGrid.clampPlayerFeet(option);
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
    feel.chargeHum(false);
    _charge = 0;
    _chargeHeld = 0;
    _swivel = 0;
    _sweepElev = 0;
    _sweepDir = 1;
    _sweepSpeed = 1;
    _aimTarget = null;
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
  void onRemove() {
    feel.chargeHum(false);
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (paused || phase == MatchPhase.paused) return;
    super.update(dt);
    _tickEntrance(dt);
    if (phase == MatchPhase.fight) fightSeconds += dt;
    if (_settling) {
      _settleTime += dt;
      if (!_shotsInFlight || _settleTime >= settleCapSeconds) {
        resolveKnockouts();
      }
    }
    _tickHound(dt);
    if (_armorTime > 0) {
      _armorTime -= dt;
      if (_armorTime <= 0) {
        for (final kid in players) {
          kid.armored = false;
        }
        hudRevision.value++;
      }
    }
    _tickMove(dt);
    if (_charging) {
      final kid = _selected;
      if (kid == null ||
          kid.isKo ||
          kid.isStunned ||
          phase != MatchPhase.fight) {
        _endActiveThrow();
      } else {
        // Straight ahead while power builds. The pan starts the frame after
        // the charge passes [ThrowPhysics.sweepStartCharge].
        final panning = _charge >= ThrowPhysics.sweepStartCharge;
        _chargeHeld += dt;
        _charge = ThrowPhysics.chargeForHold(
          _chargeHeld,
          _playerChargeSeconds(),
        );
        if (panning) {
          // The sweep lingers while the line crosses a rival (in reach or
          // not), so a release on target is a fair window.
          final onLine = _scanAim(kid, _swivel, double.infinity).hit != null;
          final goal = onLine ? ThrowPhysics.aimFriction : 1.0;
          final blend = math.min(1.0, dt * ThrowPhysics.aimFrictionBlend);
          _sweepSpeed += (goal - _sweepSpeed) * blend;
          _stepPan(kid, dt);
        }
        _swivel = _sweepElev;
        _aimDir = ThrowPhysics.aimForElevation(_swivel, facingRight: true);
        _aimTarget = _scanAim(
          kid,
          _swivel,
          ThrowPhysics.rangeForCharge(_charge),
        ).hit;
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
