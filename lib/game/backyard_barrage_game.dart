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
import '../audio/game_audio.dart';
import '../feel/feel_bus.dart';
import '../meta/difficulty.dart';
import '../meta/game_settings.dart';
import '../meta/meta_state.dart';
import '../meta/play_mode.dart';
import '../meta/power_up.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/arena.dart';
import '../seasons/season.dart';
import '../seasons/season_kit.dart';
import 'arena_grid.dart';
import 'boss.dart';
import 'combat_rules.dart';
import 'game_art.dart';
import 'crew_carry.dart';
import 'crew_snapshot.dart';
import 'enemy_perks.dart';
import 'rival_type.dart';
import 'components/boss_controller.dart';
import 'components/charge_indicator.dart';
import 'components/coin_pop.dart';
import 'components/coin_carry.dart';
import 'components/enemy_controller.dart';
import 'components/fire_wave.dart';
import 'components/fort_component.dart';
import 'components/hound_component.dart';
import 'components/ice_spike.dart';
import 'components/impact_burst.dart';
import 'components/kid_component.dart';
import 'components/reward_float.dart';
import 'components/shield_pile.dart';
import 'components/lob_projectile.dart';
import 'components/overlay_banner.dart';
import 'components/perk_badges.dart';
import 'components/splash_particles.dart';
import 'throw_physics.dart';
import 'wave_reward.dart';

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
  final Map<int, Sprite> _rivalFortIntact = {};
  final Map<int, Sprite> _rivalFortDamaged = {};
  Sprite? _rivalFortCollapsed;
  final List<Sprite> _propSprites = [];
  final List<SpriteComponent> _props = [];

  final List<KidComponent> players = [];
  final List<KidComponent> enemies = [];
  final Map<KidComponent, RivalType> _rivalTypes = {};

  /// What kind of rival [kid] is. Player kids and unknowns read as ghosts.
  RivalType rivalTypeOf(KidComponent kid) =>
      _rivalTypes[kid] ?? RivalType.snowGhost;

  // Bosses: art loaded once, and the boss on the yard (if any).
  final Map<BossType, KidPoseSprites> _bossPoses = {};
  final Map<BossType, List<Sprite>> _bossSpecials = {};
  Sprite? _magmaBall;
  Sprite? _ogreBall;
  Sprite? _bunkerBuster;
  Sprite? _shieldPile;

  /// A kid's shield took its last hit: leave it broken in the snow.
  void _dropShield(KidComponent kid) {
    final sprite = _shieldPile;
    if (sprite == null || kid.shieldSpot == null || !kid.isMounted) return;
    world.add(ShieldPile.under(kid, sprite));
  }

  Sprite? _magmaImpact;
  Sprite? _fireWaveSprite;
  Sprite? _shockwaveSprite;
  List<Sprite> _spikeSprites = const [];
  KidComponent? _boss;
  BossType? _bossType;
  BossType? _lastBoss;
  bool _bossRewarded = false;
  final Set<LobProjectile> _magmaShots = {};

  /// Body box of a boss next to a rival's [ArenaGrid.kidSize]: its hit
  /// circle is this much bigger too.
  static const double bossSizeScale = 1.6;

  /// Boss art is drawn this much over its body box (about twice a rival).
  static const double bossDrawScale = 1.5;

  /// The boss on the yard this wave, or null.
  KidComponent? get boss => _boss;
  BossType? get bossType => _bossType;
  bool get isBossWave => BossRules.isBossWave(wave);

  @visibleForTesting
  BossController? get bossBrain =>
      _boss?.children.whereType<BossController>().firstOrNull;

  late FortComponent fort;
  late FortComponent enemyFort;

  /// Bought extra forts (More forts), placed at random each wave.
  final List<FortComponent> extraForts = [];

  /// Every fort a snowball can meet.
  List<FortComponent> get _allForts => [
    fort,
    ...extraForts,
    enemyFort,
    ...enemyExtraForts,
  ];

  /// Extra rival forts this wave ([RivalFortRules.extras]).
  final List<FortComponent> enemyExtraForts = [];

  /// Perks each rival carries this wave (from wave 10).
  final Map<KidComponent, List<HeldPerk>> _perks = {};

  @visibleForTesting
  List<HeldPerk> perksOf(KidComponent kid) => _perks[kid] ?? const [];

  @visibleForTesting
  void debugGivePerks(KidComponent kid, List<HeldPerk> perks) =>
      _givePerks(kid, perks);

  @visibleForTesting
  void debugTickPerks(double dt) => _tickPerks(dt);

  /// Rival team Frost armor time left.
  double _rivalArmorTime = 0;
  double get rivalArmorLeft => _rivalArmorTime;
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

  /// What this wave paid, newest last, for the wave report: power-ups from
  /// a scared hound or a boss, knockout coins, and the clear bonus.
  final List<WaveReward> waveRewards = [];

  /// Adds [reward] to the wave report, folding it into an earlier one of
  /// the same item from the same source ("+2 Revive" for a boss that
  /// paid two).
  void _addReward(WaveReward reward) {
    final index = waveRewards.indexWhere(
      (r) => r.item == reward.item && r.source == reward.source,
    );
    if (index < 0) {
      waveRewards.add(reward);
      return;
    }
    waveRewards[index] = waveRewards[index].plus(reward.amount);
  }

  /// Rivals each kid knocked out this wave (by index).
  final List<int> kidKos = [0, 0, 0];

  void _creditKo(KidComponent? thrower) {
    if (thrower == null || thrower.side != KidSide.player) return;
    final index = players.indexOf(thrower);
    if (index >= 0 && index < kidKos.length) kidKos[index] += 1;
  }

  /// Points the last wave clear added to the score.
  int lastWaveScore = 0;

  /// What the last defeat did: the wave a retry starts on, coins lost, and
  /// coins refunded (Arcade's checkpoint). Null before any defeat.
  CheckpointResult? lastDefeat;

  /// The crew as it went down, and as the loss left it (before any
  /// shopping), for the defeat summary.
  CrewSnapshot? defeatBefore;
  CrewSnapshot? defeatAfter;

  /// Points the last defeat took off the score.
  int lastScorePenalty = 0;

  /// Health for each kid going into the next wave, set at a wave clear
  /// after the kids still out have left. Null starts everyone full.
  List<int>? _pendingCrewHp;

  /// Rivals still offstage this wave, in walk-on order.
  final List<RivalType> _reserve = [];
  double _walkOnTimer = 0;

  /// Rivals walking on mid-fight, and where each is headed.
  final List<({KidComponent kid, Vector2 goal})> _arrivals = [];

  /// Rivals waiting offstage to walk on.
  int get rivalsWaiting => _reserve.length;

  /// Rivals still standing on the yard, not counting those waiting.
  int get rivalsOnField => enemies.where((kid) => !kid.isKo).length;

  /// Walk-on pace. Not the locked drag rate.
  static const double entranceSpeed = 280;

  static const double _offstage = 180;

  /// Seconds spent in the fight this run. Shop, pause, and banners do not
  /// count.
  double fightSeconds = 0;

  /// Fight seconds since the last interstitial that actually showed (or
  /// since the app opened).
  double _playSinceAd = 0;

  /// Waves won since the last interstitial that actually showed.
  int _wavesSinceAd = 0;
  var _adInFlight = false;

  @visibleForTesting
  double get playSinceAd => _playSinceAd;

  /// Count [seconds] of fighting toward the next interstitial.
  @visibleForTesting
  void debugAddPlayTime(double seconds) => _playSinceAd += seconds;

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

  /// Freeze all time left. The HUD frosts the screen edges meanwhile.
  double _freezeTime = 0;
  double get freezeLeft => _freezeTime;

  /// True while that power-up is armed for the next throw (or Frost armor
  /// is up). The HUD lights its button.
  bool isPowerUpLive(PowerUp item) => switch (item) {
    PowerUp.frostArmor => _armorTime > 0,
    PowerUp.fortCracker => _crackerArmed,
    PowerUp.bigSplat => _splatArmed,
    PowerUp.powerThrow => _powerArmed,
    PowerUp.freezeAll || PowerUp.hotCocoa || PowerUp.revive => false,
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
    if (item == PowerUp.revive && !players.any((kid) => kid.isKo)) {
      return false; // nobody to bring back; keep the potion
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
        _freezeTime = PowerUp.freezeSeconds;
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
      case PowerUp.revive:
        final down = players.firstWhere((kid) => kid.isKo);
        down
          ..revive()
          ..shieldHits = meta.kidShield(players.indexOf(down))
          ..armored = _armorTime > 0
          ..syncDepth();
        _burst(down.hitCenter, depthY: down.hitCenter.y, power: 0.8);
        if (_selected == null || _selected!.isKo) _setSelected(down);
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
    if (isLoaded) {
      _bg.sprite = _backdrop(_kit);
      _scatterProps();
    }
  }

  /// Boss renders share the rivals' 512² framing (feet on y=471), so they
  /// load with the same square crop.
  Future<Sprite> _bossSprite(String path) => loadSprite(
    path,
    srcPosition: Vector2(20.5, 0),
    srcSize: Vector2.all(471),
  );

  Future<void> _loadBossArt() async {
    for (final type in BossType.values) {
      Future<Sprite> pose(String name) => _bossSprite(BossArt.pose(type, name));
      final windup = await pose('windup');
      final idle = await pose('idle');
      _bossPoses[type] = KidPoseSprites(
        idle: idle,
        walk: await _bossSprite(BossArt.walk(type).first),
        charge: windup,
        throwPose: await pose('throw'),
        hit: await pose('hit'),
        ko: await pose('ko'),
        pickup: idle,
        turn30l: windup,
        turn15l: windup,
        turn15r: windup,
        turn30r: windup,
        koDrop: 0,
        drawScale: bossDrawScale,
        walkCycle: [
          for (final path in BossArt.walk(type)) await _bossSprite(path),
        ],
      );
      _bossSpecials[type] = [
        for (final path in BossArt.specials(type)) await _bossSprite(path),
      ];
    }
    _magmaBall = await loadSprite(BossArt.magmaBall);
    _ogreBall = await loadSprite(BossArt.ogreBall);
    _magmaImpact = await loadSprite(BossArt.magmaImpact);
    _fireWaveSprite = await loadSprite(BossArt.fireWave);
    _shockwaveSprite = await loadSprite(BossArt.shockwave);
    _spikeSprites = [
      for (final path in BossArt.iceSpikes) await loadSprite(path),
    ];
  }

  /// Walks this wave's boss on: a random one (never the last one again),
  /// tougher each time a boss comes back.
  void _spawnBoss() {
    final type = BossRules.pick(_rng, last: _lastBoss);
    _lastBoss = type;
    _bossType = type;
    _bossRewarded = false;
    final hits = BossRules.hits(
      feel.settings.difficulty,
      BossRules.appearance(wave),
    );
    final kid = KidComponent(
      side: KidSide.enemy,
      poses: _bossPoses[type]!,
      position: Vector2.zero(),
      size: Vector2.all(ArenaGrid.kidSize * bossSizeScale),
      maxHp: hits,
    )..isBoss = true;
    final brain = BossController(
      host: kid,
      type: type,
      players: players,
      rng: _rng,
      difficulty: feel.settings.difficulty,
      isFighting: () => phase == MatchPhase.fight && !_settling,
      specialSprites: _bossSpecials[type]!,
      onThrow: _bossThrow,
      onWaveWindup: (boss, laneY) {
        world.add(
          WaveWarning(
            laneY: laneY,
            startX: boss.position.x - 40,
            seconds: BossRules.waveWindupSeconds,
          ),
        );
        feel.boss(AudioCues.magmaWaveCharge);
      },
      onWave: _bossWave,
      onHop: (_) => feel.boss(AudioCues.ogreHop),
      onSlam: _bossSlam,
    );
    final goal = ArenaGrid.cellCenter(KidSide.enemy, brain.homeColumn, 3);
    kid.position = Vector2(worldWidth + _offstage, goal.y);
    kid.setWalking(true);
    kid.syncDepth();
    enemies.add(kid);
    world.add(kid);
    _entrance.add((kid: kid, goal: goal));
    kid.add(brain);
    _boss = kid;
    _givePerks(
      kid,
      EnemyPerkRules.rollBoss(
        wave,
        BossRules.appearance(wave),
        feel.settings.difficulty,
        _rng,
      ),
    );
  }

  /// A boss lobs its big ball (magma, or a giant snowball). It bursts
  /// where it lands into a shockwave: double damage at the middle, one hit
  /// for anyone caught in the ring ([_bossBlast]).
  void _bossThrow(KidComponent boss, KidComponent target, Vector2 aim) {
    final magma = _bossType == BossType.magma;
    feel.boss(magma ? AudioCues.magmaThrow : AudioCues.ogreThrow);
    final shot = _onEnemyFire(
      boss,
      target,
      1,
      aimAt: aim,
      sprite: magma ? _magmaBall : _ogreBall,
      radiusScale: 1.6,
      quiet: true,
      magma: magma,
    );
    if (shot == null) return;
    // Drawn as big as the ball the boss holds up in its windup.
    shot.size.scale(bossBallDrawScale);
    _bossShots.add(shot);
  }

  /// The Fort cracker ball draws this much bigger than a snowball.
  static const double bunkerBusterDrawScale = 1.5;

  /// Boss balls draw this much bigger than their hit size.
  static const double bossBallDrawScale = 1.8;

  /// Boss shockwave: everyone inside [bossBlastRadius] (and a row and a
  /// half up or down) takes a hit; inside [bossBlastCore] of that, or the
  /// kid the ball struck, takes two.
  static const double bossBlastRadius = 95;
  static const double bossBlastCore = 0.35;

  final Set<LobProjectile> _bossShots = {};

  void _bossBlast(Vector2 at, {KidComponent? struck}) {
    final ring = _shockwaveSprite;
    if (ring != null) {
      world.add(
        _FadingSprite(
          sprite: ring,
          position: Vector2(at.x, at.y + ArenaGrid.bodyLift),
          size: Vector2(bossBlastRadius * 2.4, bossBlastRadius * 1.2),
          seconds: 0.45,
        ),
      );
    }
    _punch(knockedOut: false);
    for (final kid in List.of(players)) {
      if (kid.isKo) continue;
      final dx = (kid.hitCenter.x - at.x) / bossBlastRadius;
      final dy = (kid.hitCenter.y - at.y) / (ArenaGrid.rowStep * 1.5);
      final d = math.sqrt(dx * dx + dy * dy);
      if (!identical(kid, struck) && d > 1) continue;
      _bossHitKid(
        kid,
        hits: identical(kid, struck) || d <= bossBlastCore ? 2 : 1,
      );
    }
  }

  /// Big splat: the throw bursts where it lands, one hit on every rival in
  /// the splash and two near its middle. The rival it struck already took
  /// its normal hit.
  void _splatBlast(LobProjectile shot, {KidComponent? struck}) {
    final at = shot.hitPosition;
    final radius = MetaState.baseBlastRadius * PowerUp.splatScale * 1.5;
    _burst(shot.position, power: 2);
    if (shot.owner?.side == KidSide.enemy) {
      // A rival's Big splat: one hit on every kid in the splash.
      for (final kid in List.of(players)) {
        if (kid.isKo || identical(kid, struck)) continue;
        final dx = (kid.hitCenter.x - at.x) / radius;
        final dy = (kid.hitCenter.y - at.y) / (ArenaGrid.rowStep * 1.5);
        if (dx * dx + dy * dy > 1) continue;
        _bossHitKid(kid);
      }
      return;
    }
    if (_rivalArmorTime > 0) {
      feel.armorBlocked();
      return;
    }
    for (final rival in List.of(enemies)) {
      if (rival.isKo || identical(rival, struck)) continue;
      final dx = (rival.hitCenter.x - at.x) / radius;
      final dy = (rival.hitCenter.y - at.y) / (ArenaGrid.rowStep * 1.5);
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1) continue;
      final hits = d <= bossBlastCore ? 2 : 1;
      for (var i = 0; i < hits && !rival.isKo; i++) {
        rival.takeHit(stunScale: meta.stunScaleFor(ally: false));
      }
      rival.recoil(shot.facing);
      _rivalHurt(rival);
      if (rival.isKo) _creditKo(shot.owner);
    }
    resolveKnockouts();
  }

  /// The armed power-up shows on the throw itself: the ball is drawn as
  /// that power-up's icon.
  Sprite? _armedSprite(bool manual) {
    if (!manual) return null;
    if (_crackerArmed) {
      return _bunkerBuster ?? _powerUpSprites[PowerUp.fortCracker];
    }
    if (_splatArmed) return _powerUpSprites[PowerUp.bigSplat];
    if (_powerArmed) return _powerUpSprites[PowerUp.powerThrow];
    return null;
  }

  final Map<PowerUp, Sprite> _powerUpSprites = {};

  void _bossWave(KidComponent boss, double laneY) {
    feel.boss(AudioCues.magmaWaveRelease);
    world.add(
      FireWave(
        sprite: _fireWaveSprite!,
        laneY: laneY,
        startX: boss.position.x - 60,
        players: players,
        forts: [fort, ...extraForts],
        onKidHit: _bossHitKid,
        onFortHit: (cover) {
          final wasStanding = cover.standing;
          for (var i = 0; i < FireWave.fortDamage; i++) {
            cover.takeHit();
          }
          _burst(Vector2(cover.position.x, laneY), power: 1.2);
          if (wasStanding && cover.isCollapsed) {
            feel.fortCollapsed();
          } else {
            feel.fortHit();
          }
          _publishHud();
        },
      ),
    );
  }

  void _bossSlam(KidComponent boss) {
    feel.boss(AudioCues.ogreCrash);
    _punch(knockedOut: true);
    final ring = _shockwaveSprite;
    if (ring != null) {
      world.add(
        _FadingSprite(
          sprite: ring,
          position: boss.position.clone(),
          size: Vector2(320, 160),
          seconds: 0.5,
        ),
      );
    }
    var sounded = false;
    for (final kid in players) {
      if (kid.isKo) continue;
      world.add(
        IceSpike(
          frames: _spikeSprites,
          feet: kid.position.clone(),
          warnSeconds: BossRules.spikeWarnSeconds(feel.settings.difficulty),
          players: players,
          onKidHit: _bossHitKid,
          onBurst: () {
            if (sounded) return;
            sounded = true;
            feel.boss(AudioCues.iceSpikes);
          },
        ),
      );
    }
  }

  /// A heat wave, ice spike, or boss blast lands on [kid]: the same as a
  /// snowball hit (Frost armor and shields block it). [hits] 2 costs an
  /// extra heart (or an extra shield) first, but never knocks out by
  /// itself; the last hit is the usual stun.
  void _bossHitKid(KidComponent kid, {int hits = 1}) {
    if (phase != MatchPhase.fight || kid.isKo) return;
    if (_armorTime > 0) {
      feel.armorBlocked();
      return;
    }
    final selected = identical(kid, _selected);
    final scale =
        meta.kidPoise(math.max(0, players.indexOf(kid))) *
        _tuning().allyStunScale;
    for (var i = 1; i < hits; i++) {
      if (kid.blockWithShield()) {
        continue;
      } else if (kid.hp > 1) {
        kid.hp -= 1;
      }
    }
    kid.takeHit(stunScale: scale);
    kid.recoil(-1);
    _burst(kid.hitCenter, depthY: kid.hitCenter.y);
    feel.kidHit(knockedOut: kid.isKo, season: meta.season);
    _punch(knockedOut: kid.isKo);
    if (selected && (kid.isKo || kid.isStunned)) {
      _endActiveThrow();
      _setSelected(_firstReady(players) ?? _firstLiving(players));
    }
    resolveKnockouts();
  }

  void _clearBossFx() {
    for (final fx in [
      ...world.children.whereType<FireWave>(),
      ...world.children.whereType<WaveWarning>(),
      ...world.children.whereType<IceSpike>(),
      ...world.children.whereType<_FadingSprite>(),
    ]) {
      fx.removeFromParent();
    }
    _magmaShots.clear();
    _bossShots.clear();
  }

  /// Feet spots for yard props, clear of both crews' columns and the river:
  /// along the back of the yard, and the far front-right corner (the
  /// front-left holds the power-up buttons).
  static const List<(double, double)> propSpots = [
    (55, 418),
    (425, 410),
    (825, 410),
    (1225, 418),
    (1232, 708),
  ];

  /// How many props a yard gets.
  static const int propCount = 4;

  /// Props on the yard now, for tests.
  @visibleForTesting
  List<SpriteComponent> get props => List.unmodifiable(_props);

  /// Fresh scenery: [propCount] different props on random [propSpots].
  /// Decoration only; nothing collides with them.
  void _scatterProps() {
    for (final prop in _props) {
      prop.removeFromParent();
    }
    _props.clear();
    if (_propSprites.isEmpty) return;
    final spots = List.of(propSpots)..shuffle(_rng);
    final sprites = List.of(_propSprites)..shuffle(_rng);
    for (var i = 0; i < propCount && i < spots.length; i++) {
      final (x, y) = spots[i];
      final scale = ArenaGrid.depthScale(y, groundTrack: false);
      final prop = SpriteComponent(
        sprite: sprites[i % sprites.length],
        size: Vector2.all(160 * scale),
        position: Vector2(x, y),
        anchor: Anchor.bottomCenter,
        priority: ArenaGrid.depthOrder(y),
      );
      _props.add(prop);
      world.add(prop);
    }
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
      _fortIntact[stage] = await loadSprite(GameArt.fort(stage));
      _fortDamaged[stage] = await loadSprite(
        GameArt.fort(stage, damaged: true),
      );
      _rivalFortIntact[stage] = await loadSprite(
        GameArt.fort(stage, rival: true),
      );
      _rivalFortDamaged[stage] = await loadSprite(
        GameArt.fort(stage, damaged: true, rival: true),
      );
    }
    _fortCollapsed = await loadSprite(GameArt.fortCollapsed());
    _rivalFortCollapsed = await loadSprite(GameArt.fortCollapsed(rival: true));
    KidComponent.armorSprite = await loadSprite(GameArt.iceBubble);
    KidComponent.shieldSprite = await loadSprite(GameArt.ironShield);
    KidComponent.shieldCrackedSprite = await loadSprite(
      GameArt.ironShieldCracked,
    );
    _shieldPile = await loadSprite(GameArt.ironShieldDestroyed);
    _bunkerBuster = await loadSprite(GameArt.bunkerBuster);
    for (final path in GameArt.props) {
      _propSprites.add(await loadSprite(path));
    }
    for (final item in PowerUp.values) {
      _powerUpSprites[item] = await loadSprite(GameArt.powerUp(item));
    }

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
      land: await hound('land'),
      hit: await hound('hit'),
    );
    await _loadBossArt();
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
    _scatterProps();

    fort = FortComponent(
      side: KidSide.player,
      sprite: _fortIntact[meta.fortStage]!,
      position: ArenaGrid.fortAnchor(),
      size: ArenaGrid.fortDrawSize,
    );
    world.add(fort);
    enemyFort = FortComponent(
      side: KidSide.enemy,
      sprite: _rivalFortIntact[1]!,
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
    for (var i = 0; i < players.length; i++) {
      players[i].applyPoses(kit.posesForKid(i));
    }
    for (final kid in enemies) {
      if (kid.isBoss) continue;
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
    waveRewards.clear();
    _clearWaitsOnHound = false;
    // A float still up when the report paused the yard goes with it.
    for (final float in world.children.whereType<RewardFloat>().toList()) {
      float.removeFromParent();
    }
    kidKos.setAll(0, [0, 0, 0]);
    phase = MatchPhase.entering;
    _entrance.clear();

    if (meta.mode == PlayMode.campaign) {
      if (isBossWave) {
        // A boss wave is its own checkpoint: a loss retries just the boss.
        if (meta.ledger.checkpointWave != wave) {
          meta.takeCheckpoint(wave, exact: true);
        }
      } else if ((MetaState.opensStage(wave) || !meta.ledger.hasCheckpoint) &&
          meta.ledger.checkpointWave != MetaState.stageStart(wave)) {
        meta.takeCheckpoint(wave);
      }
    }

    final crewHp = _nextCrewHp();
    while (players.length > meta.crewSize) {
      players.removeLast().removeFromParent();
    }
    while (players.length < meta.crewSize) {
      final kid = _makeKid(KidSide.player, players.length);
      players.add(kid);
      world.add(kid);
    }
    _waveStartHp = List<int>.of(crewHp);
    for (var i = 0; i < players.length; i++) {
      final kid = players[i];
      kid.maxHp = meta.kidMaxHp(i);
      final goal = ArenaGrid.slot(KidSide.player, i);
      if (crewHp[i] <= 0) {
        // Knocked out in an earlier wave and not brought back.
        kid.benchOut();
        kid.position = Vector2(-_offstage - i * 36, goal.y);
        continue;
      }
      kid.revive();
      kid.hp = crewHp[i];
      kid.shieldHits = meta.kidShield(i);
      kid.syncHealthSeen();
      kid.position = Vector2(-_offstage - i * 36, goal.y);
      kid.setWalking(true);
      kid.syncDepth();
      _entrance.add((kid: kid, goal: goal));
    }
    _setSelected(_firstLiving(players));
    _ensureAllyBrains();

    // A boss wave is the boss plus a growing escort; the first comes alone.
    final bossWave = isBossWave;
    if (bossWave) _spawnBoss();
    final count = bossWave
        ? BossRules.supportFor(wave)
        : CombatRules.enemyCountForWave(wave);
    final lineup = RivalRoster.forWave(count: count, rng: _rng);
    final first = bossWave ? 1 : 0;
    final starting = math.min(count, WavePlan.fieldStart - first);
    for (var i = 0; i < starting; i++) {
      final kid = _spawnRival(lineup[i], i + first);
      kid.position.x = worldWidth + _offstage + (i + first) * 36;
      kid.syncDepth();
    }
    _reserve.addAll(lineup.skip(starting));
    _walkOnTimer = WavePlan.walkOnGap;

    while (extraForts.length > meta.extraForts) {
      extraForts.removeLast().removeFromParent();
    }
    while (extraForts.length < meta.extraForts) {
      final extra = FortComponent(
        side: KidSide.player,
        sprite: _fortIntact[meta.fortStage]!,
        position: ArenaGrid.fortAnchor(),
        size: ArenaGrid.fortDrawSize,
      );
      extraForts.add(extra);
      world.add(extra);
    }
    for (final cover in [fort, ...extraForts]) {
      cover.applyStage(
        nextStage: meta.fortStage,
        intactSprite: _fortIntact[meta.fortStage]!,
        damagedSprite: _fortDamaged[meta.fortStage]!,
        collapsedSprite: _fortCollapsed!,
      );
      if (meta.fortBonusHp > 0) {
        cover.maxHp += meta.fortBonusHp;
        cover.hp = cover.maxHp;
      }
    }
    // The rival side builds up too: a random stage, and from wave 8 extra
    // forts of the same stage.
    final rivalStage = RivalFortRules.stage(wave, _rng);
    final rivalExtras = RivalFortRules.extras(wave, _rng);
    while (enemyExtraForts.length > rivalExtras) {
      enemyExtraForts.removeLast().removeFromParent();
    }
    while (enemyExtraForts.length < rivalExtras) {
      final extra = FortComponent(
        side: KidSide.enemy,
        sprite: _rivalFortIntact[rivalStage]!,
        position: ArenaGrid.fortAnchor(KidSide.enemy),
        size: ArenaGrid.fortDrawSize,
      );
      enemyExtraForts.add(extra);
      world.add(extra);
    }
    for (final cover in [enemyFort, ...enemyExtraForts]) {
      cover.applyStage(
        nextStage: rivalStage,
        intactSprite: _rivalFortIntact[rivalStage]!,
        damagedSprite: _rivalFortDamaged[rivalStage]!,
        collapsedSprite: _rivalFortCollapsed!,
      );
    }
    fort.placeOnRow(ArenaGrid.rollFortRow(_rng));
    enemyFort.placeOnRow(ArenaGrid.rollFortRow(_rng));
    _layoutExtraForts(fort, extraForts);
    _layoutExtraForts(enemyFort, enemyExtraForts);
    _showWaveIntro();
    _publishHud();
    unawaited(feel.enterBattle(meta.season));
  }

  /// Drops each extra fort on a random spot in its side's half that does
  /// not overlap another fort: a different column pair, or at least two
  /// rows apart. A bad first pick can leave no room for the next, so the
  /// whole layout is retried; a fort that still finds no room sits the
  /// wave out (hidden, no cover).
  void _layoutExtraForts(FortComponent main, List<FortComponent> extras) {
    List<(int, int)>? best;
    for (var attempt = 0; attempt < 40; attempt++) {
      final taken = <(int, int)>[(main.coverColumn, main.coverRow)];
      final layout = <(int, int)>[];
      for (var i = 0; i < extras.length; i++) {
        final spots = <(int, int)>[
          for (var row = 1; row < ArenaGrid.rows - 1; row++)
            for (
              var column = 0;
              column < ArenaGrid.columnsPerSide - 1;
              column++
            )
              if (taken.every(
                (other) =>
                    (other.$1 - column).abs() >= 2 ||
                    (other.$2 - row).abs() >= 2,
              ))
                (column, row),
        ];
        if (spots.isEmpty) break;
        final pick = spots[_rng.nextInt(spots.length)];
        taken.add(pick);
        layout.add(pick);
      }
      if (best == null || layout.length > best.length) best = layout;
      if (layout.length == extras.length) break;
    }
    for (var i = 0; i < extras.length; i++) {
      final extra = extras[i];
      if (i < best!.length) {
        extra
          ..opacity = 1
          ..placeAt(row: best[i].$2, column: best[i].$1);
      } else {
        extra
          ..opacity = 0
          ..hp = 0;
      }
    }
  }

  void _publishHud() {
    var signature = Object.hash(
      wave,
      meta.coins,
      fort.hp,
      fort.maxHp,
      players.length,
      enemies.length,
      _reserve.length,
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

  /// Iron shield placement on the idle art (from the artist's
  /// `shield_offsets.json`): the crew holds it in the front hand; rivals
  /// face left, so theirs is flipped. Measured on the frost kid and used
  /// for every rival.
  static const _crewShield = (x: 0.60, y: 0.585, side: 0.318, mirror: false);
  static const _rivalShield = (x: 0.40, y: 0.62, side: 0.325, mirror: true);

  KidComponent _makeKid(KidSide side, int slot) {
    final player = side == KidSide.player;
    return KidComponent(
        side: side,
        poses: player ? _kit.posesForKid(slot) : _kit.enemyPoses,
        position: ArenaGrid.slot(side, slot),
        size: Vector2.all(ArenaGrid.kidSize),
        maxHp: player ? meta.kidMaxHp(slot) : _tuning().enemyHitsToKo,
      )
      ..shieldSpot = player ? _crewShield : null
      ..onShieldBroken = _dropShield;
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
    kid.shieldSpot = _rivalShield;
    kid.onShieldBroken = _dropShield;
    kid.glint = profile.glint;
    kid.aura = profile.aura;
    final at = profile.glintAt;
    if (at != null) kid.glintAt = Vector2(at.$1, at.$2);
    _rivalTypes[kid] = type;
    return kid;
  }

  /// Adds a rival of [type] offstage, walking toward its post. The first
  /// five use the fixed slots; later ones take a free cell.
  KidComponent _spawnRival(RivalType type, int index, {bool walkOn = false}) {
    final rival = RivalProfile.of(type);
    final kid = _makeRival(type, index);
    final perks = EnemyPerkRules.rollRival(
      wave,
      feel.settings.difficulty,
      _rng,
    );
    final Vector2 goal;
    if (index < ArenaGrid.enemySlots.length) {
      final slot = ArenaGrid.enemySlots[index];
      // Slot rows are distinct, so a type's home column never stacks kids.
      goal = ArenaGrid.cellCenter(
        KidSide.enemy,
        rival.holdColumn ?? slot.$1,
        slot.$2,
      );
    } else {
      goal = _freeRivalCell(rival.holdColumn);
    }
    kid.position = Vector2(worldWidth + _offstage, goal.y);
    kid.setWalking(true);
    kid.syncDepth();
    enemies.add(kid);
    world.add(kid);
    if (walkOn) {
      _arrivals.add((kid: kid, goal: goal));
    } else {
      _entrance.add((kid: kid, goal: goal));
    }
    final profile = _tuning();
    final gap = profile.throwGap(_rng.nextDouble());
    final stagger = (gap * (0.75 + (index % 5) * 0.1)).clamp(
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
        isFighting: () =>
            phase == MatchPhase.fight &&
            !_settling &&
            !_arrivals.any((a) => identical(a.kid, kid)),
        playerChargeSeconds: _baseChargeSeconds,
        profile: rival,
        onWindup: rival.glint ? feel.frostGlint : null,
        windupBoost: _quickHands(perks),
      ),
    );
    _givePerks(kid, perks);
    return kid;
  }

  double _quickHands(List<HeldPerk> perks) {
    for (final held in perks) {
      if (held.perk == EnemyPerk.quickHands) {
        return EnemyPerkRules.windupScale(held.level);
      }
    }
    return 1;
  }

  /// Puts [perks] on [kid]: shields up front, badges over its head.
  void _givePerks(KidComponent kid, List<HeldPerk> perks) {
    if (perks.isEmpty) return;
    _perks[kid] = perks;
    for (final held in perks) {
      if (held.perk == EnemyPerk.shield) {
        kid.shieldHits += held.level;
        held.uses = 0; // shown by the shield badge, not a perk icon
      }
    }
    kid.add(
      PerkBadges(
        host: kid,
        perks: perks,
        icons: _powerUpSprites,
        countdownSeconds: EnemyPerkRules.countdown(feel.settings.difficulty),
      ),
    );
  }

  /// A hurt rival with an unused Hot cocoa drinks it: +level hearts (a
  /// boss heals a quarter of its health).
  void _rivalHurt(KidComponent kid) {
    if (kid.isKo || kid.hp >= kid.maxHp) return;
    for (final held in _perks[kid] ?? const <HeldPerk>[]) {
      if (held.perk != EnemyPerk.cocoa || held.spent) continue;
      held.uses = 0;
      final heal = kid.isBoss ? (kid.maxHp / 4).ceil() : held.level;
      kid.hp = math.min(kid.maxHp, kid.hp + heal);
      world.add(
        CoinPop(
          amount: heal,
          label: '+$heal ♥',
          position: kid.hitCenter - Vector2(0, 90),
        ),
      );
      feel.powerUpUsed(PowerUp.hotCocoa);
      _publishHud();
      return;
    }
  }

  /// Area perks count down while the fight runs; one that reaches zero on
  /// a rival still standing goes off for its whole side.
  void _tickPerks(double dt) {
    if (_rivalArmorTime > 0) {
      _rivalArmorTime -= dt;
      if (_rivalArmorTime <= 0) {
        for (final rival in enemies) {
          rival.armored = false;
        }
      }
    }
    if (phase != MatchPhase.fight || _settling) return;
    for (final entry in _perks.entries) {
      final kid = entry.key;
      if (kid.isKo) continue;
      for (final held in entry.value) {
        if (!held.perk.area || held.spent) continue;
        held.countdown -= dt;
        if (held.countdown > 0) continue;
        held.uses = 0;
        _fireAreaPerk(kid, held);
      }
    }
  }

  void _fireAreaPerk(KidComponent kid, HeldPerk held) {
    final item = held.perk.item;
    if (item != null) feel.powerUpUsed(item);
    final label = switch (held.perk) {
      EnemyPerk.freezeAll => 'Freeze!',
      EnemyPerk.teamCocoa => 'Cocoa!',
      _ => 'Armor!',
    };
    world.add(
      CoinPop(
        amount: 0,
        label: label,
        position: kid.hitCenter - Vector2(0, 90),
      ),
    );
    switch (held.perk) {
      case EnemyPerk.freezeAll:
        for (final player in players) {
          if (!player.isKo) player.freeze(EnemyPerkRules.freezeSeconds);
        }
        _endActiveThrow();
      case EnemyPerk.teamCocoa:
        for (final rival in enemies) {
          if (!rival.isKo) rival.hp = math.min(rival.maxHp, rival.hp + 1);
        }
      case EnemyPerk.teamArmor:
        _rivalArmorTime = EnemyPerkRules.armorSeconds;
        for (final rival in enemies) {
          rival.armored = !rival.isKo;
        }
      default:
        break;
    }
    _publishHud();
  }

  /// A rival knocked out with potions it never used may drop each one for
  /// the crew ([EnemyPerkRules.dropChance]).
  void _dropPerks(KidComponent kid) {
    final perks = _perks.remove(kid);
    if (perks == null) return;
    for (final held in perks) {
      final item = held.perk.item;
      if (item == null || held.spent) continue;
      held.uses = 0;
      if (_rng.nextDouble() >= EnemyPerkRules.dropChance) continue;
      meta.replaceItems({...meta.items, item: meta.itemCount(item) + 1});
      _addReward(WaveReward.item(item, 'Dropped by a rival'));
      _floatRewards([item], kid.hitCenter - Vector2(0, 130));
      feel.purchased();
    }
  }

  /// A rival's throw carries its Big splat or Fort cracker: the ball is
  /// drawn as the potion and spends one use.
  void _armRivalShot(KidComponent enemy, LobProjectile shot) {
    for (final held in _perks[enemy] ?? const <HeldPerk>[]) {
      if (held.spent) continue;
      if (held.perk == EnemyPerk.bigSplat) {
        held.uses -= 1;
        shot.splat = true;
        shot.sprite = _powerUpSprites[PowerUp.bigSplat];
        return;
      }
      if (held.perk == EnemyPerk.fortCracker) {
        held.uses = 0;
        shot.cracker = true;
        final buster = _bunkerBuster;
        if (buster != null) {
          shot.sprite = buster;
          shot.size.scale(bunkerBusterDrawScale);
        } else {
          shot.sprite = _powerUpSprites[PowerUp.fortCracker];
        }
        return;
      }
    }
  }

  /// A rival cell no standing rival is on, preferring empty rows.
  Vector2 _freeRivalCell(int? column) {
    final taken = <(int, int)>{};
    final rowLoad = List.filled(ArenaGrid.rows, 0);
    for (final kid in enemies) {
      if (kid.isKo) continue;
      final cell = ArenaGrid.nearestCell(KidSide.enemy, kid.position);
      taken.add((cell.column, cell.row));
      rowLoad[cell.row] += 1;
    }
    for (final mark in _arrivals) {
      final cell = ArenaGrid.nearestCell(KidSide.enemy, mark.goal);
      taken.add((cell.column, cell.row));
      rowLoad[cell.row] += 1;
    }
    final cells = <(int, int)>[
      for (var row = 0; row < ArenaGrid.rows; row++)
        for (var col = 0; col < ArenaGrid.columnsPerSide; col++)
          if ((column == null || col == column) && !taken.contains((col, row)))
            (col, row),
    ];
    if (cells.isEmpty) {
      final row = _rng.nextInt(ArenaGrid.rows);
      return ArenaGrid.cellCenter(KidSide.enemy, column ?? 3, row);
    }
    final least = cells.map((c) => rowLoad[c.$2]).reduce(math.min);
    final best = [
      for (final c in cells)
        if (rowLoad[c.$2] == least) c,
    ];
    final pick = best[_rng.nextInt(best.length)];
    return ArenaGrid.cellCenter(KidSide.enemy, pick.$1, pick.$2);
  }

  /// Rivals waiting offstage walk on every [WavePlan.walkOnGap] seconds
  /// while fewer than [WavePlan.fieldCap] stand on the yard. At the cap,
  /// the next one walks on as soon as a rival goes down.
  @visibleForTesting
  void debugTickWalkOns(double dt) => _tickWalkOns(dt);

  void _tickWalkOns(double dt) {
    if (phase != MatchPhase.fight) return;
    final step = entranceSpeed * dt;
    _arrivals.removeWhere((mark) {
      final kid = mark.kid;
      if (kid.isKo || kid.isRemoved) return true;
      final delta = mark.goal - kid.position;
      final distance = delta.length;
      if (distance <= step || distance < 1) {
        kid.position = mark.goal.clone();
        kid.setWalking(false);
        kid.syncDepth();
        return true;
      }
      kid.position += delta / distance * step;
      kid.setWalking(true);
      kid.syncDepth();
      return false;
    });
    if (_reserve.isEmpty || _settling) return;
    if (rivalsOnField >= WavePlan.fieldCap) {
      // Full yard: the next one walks on the moment a rival goes down.
      _walkOnTimer = 0;
      return;
    }
    _walkOnTimer = math.max(0, _walkOnTimer - dt);
    if (_walkOnTimer > 0) return;
    _spawnRival(_reserve.removeAt(0), enemies.length, walkOn: true);
    _walkOnTimer = WavePlan.walkOnGap;
    _publishHud();
  }

  void _clearEnemies() {
    for (final enemy in List<KidComponent>.of(enemies)) {
      enemy.removeFromParent();
    }
    enemies.clear();
    _rivalTypes.clear();
    _reserve.clear();
    _arrivals.clear();
    _perks.clear();
    _rivalArmorTime = 0;
    _boss = null;
    _bossType = null;
  }

  // Ice hounds: rolled at wave start, released partway into the fight.
  HoundSprites? _houndSprites;
  final List<HoundComponent> _hounds = [];

  /// A hound still in play: not yet scared off and not gone. While one is,
  /// the wave does not clear, even with every rival down.
  bool get houndInPlay => _hounds.any(
    (hound) => hound.state != HoundState.flee && hound.state != HoundState.gone,
  );

  /// Every rival is down, and the clear is waiting for a hound.
  bool _clearWaitsOnHound = false;

  /// Seconds into the fight when each hound still to come is released.
  final List<double> _houndTimes = [];

  /// Seconds into the fight when each warning howl plays: one per hound,
  /// sorted.
  final List<double> _howlTimes = [];

  /// When this wave's next warning howl plays, or null (none left).
  double? get howlDueAt => _howlTimes.isEmpty ? null : _howlTimes.first;

  /// Every hound and howl time still to come, for tests.
  @visibleForTesting
  List<double> get houndTimes => List.unmodifiable(_houndTimes);
  @visibleForTesting
  List<double> get howlTimes => List.unmodifiable(_howlTimes);
  double _waveFight = 0;

  /// The most recent hound on the yard, if any.
  HoundComponent? get hound => _hounds.isEmpty ? null : _hounds.last;

  /// Hounds on the yard.
  List<HoundComponent> get hounds => List.unmodifiable(_hounds);

  /// Seconds into the fight when this wave's next hound comes, or null.
  double? get houndDueAt => _houndTimes.isEmpty ? null : _houndTimes.first;

  /// Hounds still to come this wave.
  int get houndsDue => _houndTimes.length;

  void _rollHound() {
    _clearHound();
    _waveFight = 0;
    // No hounds on a boss wave: the boss is the fight.
    if (isBossWave) return;
    _houndTimes.addAll(
      HoundComponent.scheduleFor(
        wave: wave,
        difficulty: feel.settings.difficulty,
        rng: _rng,
      ),
    );
    // Each hound is warned by a howl 2 to 6 seconds before it comes (never
    // before half a second into the fight).
    for (final at in _houndTimes) {
      final lead = howlLead + _rng.nextDouble() * howlSpread;
      _howlTimes.add(math.max(howlEarliest, at - lead));
    }
    _howlTimes.sort();
  }

  /// Earliest the howl plays, in seconds into the fight.
  static const double howlEarliest = 0.5;

  /// A howl always comes at least this long before its hound...
  static const double howlLead = 2;

  /// ...and up to this much more.
  static const double howlSpread = 4;

  void _clearHound() {
    _howlTimes.clear();
    for (final hound in _hounds) {
      hound.removeFromParent();
    }
    _hounds.clear();
    _houndTimes.clear();
  }

  /// Sends a hound down [target]'s lane now.
  @visibleForTesting
  HoundComponent releaseHound(KidComponent target) {
    final hound = HoundComponent(
      sprites: _houndSprites!,
      laneY: target.position.y,
      players: players,
      onCatch: _houndCaught,
      isLive: () => phase == MatchPhase.fight,
      difficulty: feel.settings.difficulty,
      onState: _houndSound,
    );
    _hounds.add(hound);
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
    if (!_settling && _howlTimes.isNotEmpty && _waveFight >= _howlTimes.first) {
      // Howls due on the same frame play once.
      _howlTimes.removeWhere((at) => at <= _waveFight);
      feel.houndHowl();
    }
    _hounds.removeWhere((hound) => hound.state == HoundState.gone);
    // No new hounds once the last rival is down.
    while (_houndTimes.isNotEmpty &&
        !_settling &&
        !_clearWaitsOnHound &&
        _waveFight >= _houndTimes.first) {
      _houndTimes.removeAt(0);
      final living = [
        for (final kid in players)
          if (!kid.isKo) kid,
      ];
      if (living.isEmpty) break;
      // Prefer a lane no hound is already running.
      final open = [
        for (final kid in living)
          if (!_hounds.any((h) => (h.laneY - kid.position.y).abs() < 1)) kid,
      ];
      final pool = open.isEmpty ? living : open;
      releaseHound(pool[_rng.nextInt(pool.length)]);
    }
    // A player snowball that meets a hound before it lands on the crew's
    // side (mid-leap too) scares it.
    for (final hound in _hounds) {
      if (!hound.scareable) continue;
      for (final shot in world.children.whereType<LobProjectile>()) {
        if (shot.spent || shot.owner?.side != KidSide.player) continue;
        if (!ThrowPhysics.snowballContacts(
          ground: shot.hitPosition,
          shotRadius: shot.radius,
          kidCenter: hound.groundHitCenter,
          kidRadius: HoundComponent.hitRadius,
        )) {
          continue;
        }
        _burst(shot.position, power: 0.8);
        shot.absorb();
        hound.scare();
        rewardRandomItems(1, at: hound.hitCenter, reason: 'Hound scared off');
        break;
      }
    }
  }

  /// Each earned power-up's icon pops out over [at] and floats up, side
  /// by side and one after another; repeats show once ("+2 Revive").
  void _floatRewards(List<PowerUp> items, Vector2 at) {
    final counts = <PowerUp, int>{};
    for (final item in items) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    const gap = 140.0;
    const margin = 80.0;
    final span = (counts.length - 1) * gap;
    // Centred over [at], shifted in so the row stays on screen.
    final first = (at.x - span / 2).clamp(margin, worldWidth - margin - span);
    final left = first - at.x;
    var i = 0;
    for (final entry in counts.entries) {
      final icon = _powerUpSprites[entry.key];
      if (icon == null) continue;
      world.add(
        RewardFloat(
          icon: icon,
          text: '+${entry.value} ${entry.key.label}',
          position: at + Vector2(left + i * gap, 0),
          delay: i * 0.12,
        ),
      );
      i++;
    }
  }

  /// Free power-ups: one for scaring off a hound, three for a boss, each a
  /// random item.
  @visibleForTesting
  List<PowerUp> rewardRandomItems(
    int count, {
    required Vector2 at,
    String reason = 'Bonus',
  }) {
    final given = [for (var i = 0; i < count; i++) meta.grantRandomItem(_rng)];
    for (final item in given) {
      _addReward(WaveReward.item(item, reason));
    }
    _floatRewards(given, at - Vector2(0, 80));
    feel.purchased();
    hudRevision.value++;
    unawaited(persist());
    return given;
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
    _clearBossFx();
  }

  void continueFromShop() {
    if (shoppingFromDefeat) {
      closeSkillTree();
      return;
    }
    if (phase != MatchPhase.shop) return;
    if (overlays.isActive('report')) overlays.remove('report');
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

  /// Arcade: wipe this wallet back to nothing and play from wave 1, for a
  /// new build and a new score.
  void startOverFromDefeat() {
    if (phase != MatchPhase.defeat) return;
    meta.startOver();
    lastDefeat = null;
    carriedCoins = 0;
    unawaited(persist());
    retryFromDefeat();
  }

  void retryFromDefeat() {
    if (overlays.isActive('defeat')) overlays.remove('defeat');
    if (paused) resumeEngine();
    wave = lastDefeat?.wave ?? 1;
    meta.resumeWave = 0;
    meta.resumeArena = null;
    _pendingCrewHp = null;
    _rollArena(avoidCurrent: true);
    startWave();
  }

  /// HP each player kid starts the wave on. A resumed run uses its saved
  /// crew; the first wave of a run starts full; later waves carry per
  /// [CrewCarry]. A kid bought in the shop joins at full health.
  List<int> _nextCrewHp() {
    final saved = _resumeCrewHp;
    _resumeCrewHp = null;
    final pending = _pendingCrewHp;
    _pendingCrewHp = null;
    final from = saved ?? (wave <= 1 ? null : pending);
    // One entry per kid in the crew. A kid bought in the shop is full.
    return [
      for (var i = 0; i < meta.crewSize; i++)
        from != null && i < from.length
            ? from[i].clamp(0, meta.kidMaxHp(i))
            : meta.kidMaxHp(i),
    ];
  }

  List<int> _carriedHp(List<int> now) => CrewCarry.next(
    hp: now,
    maxHp: MetaState.baseKidHp,
    maxHps: [for (var i = 0; i < now.length; i++) meta.kidMaxHp(i)],
    difficulty: feel.settings.difficulty,
    healBonus: meta.healPerWave,
    reviveOne: meta.reviveOne,
  );

  List<int>? _resumeCrewHp;
  List<int> _waveStartHp = const [];

  /// Picks up a run left through Pause → Menu: same wave (the next one if
  /// that wave was already cleared), same arena, and in Campaign the saved
  /// crew health. The bookmark is used once.
  void _takeResume() {
    if (!meta.canResume) {
      // An Arcade run that lost its bookmark (an older build, or the app
      // closed before it could save) still picks up at its checkpoint.
      if (meta.mode == PlayMode.campaign && meta.ledger.hasCheckpoint) {
        wave = meta.ledger.checkpointWave;
      }
      return;
    }
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
        meta.resumeCrewHp = List<int>.of(
          _pendingCrewHp ?? [for (final kid in players) kid.maxHp],
        );
      case MatchPhase.defeat || MatchPhase.paused:
        // Campaign starts over after a defeat. Arcade goes back to its
        // checkpoint, so the bookmark points there (crew at full health).
        meta.resumeWave = meta.mode == PlayMode.campaign
            ? (lastDefeat?.wave ?? meta.ledger.checkpointWave)
            : 0;
        meta.resumeCrewHp = null;
    }
    meta.resumeArena = meta.resumeWave > 0 ? _arena.name : null;
  }

  /// The app went to the background (home, the app switcher, a call, or
  /// the screen locking). The fight pauses behind the pause menu, the
  /// charge hum stops, and the run is saved, so if iOS closes the app
  /// while it is away, Play picks up here.
  void onAppBackgrounded() {
    if (!isLoaded) return;
    pauseMatch();
    feel.chargeHum(false);
    _bookmarkRun();
    unawaited(persist());
  }

  /// Android back: open the pause menu, or close it again.
  void onBackPressed() {
    if (phase == MatchPhase.paused) {
      resumeMatch();
    } else {
      pauseMatch();
    }
  }

  void exitToMenu() {
    _bookmarkRun();
    _offerEndAd(AdMoment.breakTime);
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
    final livingEnemies = rivalsOnField + _reserve.length;
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
    _clearWaitsOnHound = false;
    switch (outcome) {
      case RoundOutcome.defeat:
        _beginDefeat();
      case RoundOutcome.waveClear:
        if (houndInPlay) {
          // Not over until the hound is scared off or gone.
          _clearWaitsOnHound = true;
          return;
        }
        _beginWaveClear();
      case RoundOutcome.ongoing:
        break;
    }
  }

  void _beginWaveClear() {
    _clearHound();
    if (phase != MatchPhase.fight) return;
    phase = MatchPhase.clearing;
    _endActiveThrow();
    _clearShots();
    lastReward =
        MetaState.coinsForWave(wave) *
        (isBossWave ? BossRules.coinMultiplier : 1);
    meta.earn(lastReward);
    lastWaveScore = meta.scoreWaveClear(wave);
    if (killCoinsThisWave > 0) {
      waveRewards.add(WaveReward.coins(killCoinsThisWave, 'Knockouts'));
    }
    waveRewards.add(WaveReward.coins(lastReward, 'Wave $wave clear'));
    meta.noteWaveCleared(wave);
    _settleCrew();
    unawaited(persist());
    feel.waveCleared();
    _showBanner('KO!', fontSize: 56, color: const Color(0xFFFFE66D));
    _pendingBanner = _Banner.waveKo;
    _bannerTime = 0.65;
  }

  /// Carry the crew's health into the next wave, then let any kid still
  /// out leave the crew so their spot reopens in the shop.
  /// Carry the crew's health into the next wave. A kid still out stays in
  /// the crew with their skills, sitting out until revived in the wave
  /// report ([reviveKid]).
  void _settleCrew() {
    _pendingCrewHp = _carriedHp([for (final kid in players) kid.hp]);
  }

  /// Each kid's hearts going into the next wave (0 = down). The wave
  /// report shows these and can change them.
  List<int> get nextCrewHp =>
      List.unmodifiable(_pendingCrewHp ?? [for (final kid in players) kid.hp]);

  /// Wave report: pay [MetaState.reviveCost] to bring kid [index] back for
  /// the next wave at full health.
  bool reviveKid(int index) {
    final pending = _pendingCrewHp;
    if (pending == null || index >= pending.length || pending[index] > 0) {
      return false;
    }
    if (!meta.buyRevive(index)) return false;
    pending[index] = meta.kidMaxHp(index);
    _afterReportPurchase();
    return true;
  }

  /// Wave report: one heart back for kid [index] for [MetaState.healCostFor]
  /// (it rises with the wave).
  bool healKid(int index) {
    final pending = _pendingCrewHp;
    if (pending == null || index >= pending.length) return false;
    final hp = pending[index];
    if (hp <= 0 || hp >= meta.kidMaxHp(index)) return false;
    if (!meta.buyHeal(wave: wave)) return false;
    pending[index] = hp + 1;
    _afterReportPurchase();
    return true;
  }

  void _afterReportPurchase() {
    feel.purchased();
    hudRevision.value++;
    unawaited(persist());
  }

  /// Wave report → shop.
  void openShopFromReport() {
    if (overlays.isActive('report')) overlays.remove('report');
    if (!overlays.isActive('shop')) overlays.add('shop');
  }

  void _beginDefeat() {
    _clearHound();
    if (phase == MatchPhase.defeat || phase == MatchPhase.shop) return;
    phase = MatchPhase.defeat;
    _endActiveThrow();
    _clearShots();
    feel.defeated();
    lastScorePenalty = meta.scoreDefeat(wave);
    defeatBefore = CrewSnapshot.of(meta, [
      for (var i = 0; i < players.length; i++)
        KidState(
          hp: players[i].hp,
          maxHp: meta.kidMaxHp(i),
          shield: players[i].shieldHits,
          upgrades: meta.kidUpgrades(i),
        ),
    ]);
    final result = meta.resetRun(lostOn: wave);
    defeatAfter = CrewSnapshot.of(meta, [
      for (var i = 0; i < players.length; i++) KidState.fresh(meta, i),
    ]);
    lastDefeat = result;
    carriedCoins = meta.coins;
    _pendingCrewHp = null;
    if (meta.mode == PlayMode.campaign) {
      // Arcade: the Play card picks up at the checkpoint, crew at full.
      meta.resumeWave = result.wave;
      meta.resumeArena = _arena.name;
    } else {
      meta.resumeWave = 0;
      meta.resumeArena = null;
    }
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
          subtitle: [
            killCoinsThisWave > 0
                ? 'KO +$killCoinsThisWave · bonus +$lastReward'
                : '+$lastReward coins',
          ].join(' · '),
          fontSize: 42,
          color: const Color(0xFF1A2332),
        );
        _pendingBanner = _Banner.waveDone;
        _bannerTime = 0.55;
      case _Banner.waveDone:
        _pendingBanner = _Banner.none;
        _clearBanner();
        phase = MatchPhase.shop;
        _wavesSinceAd += 1;
        _offerEndAd(isBossWave ? AdMoment.bossBeaten : AdMoment.breakTime);
        // The wave report first; it hands off to the shop.
        overlays.add('report');
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
        _offerEndAd(AdMoment.defeat);
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
    final bossType = _bossType;
    if (bossType != null) {
      _showBanner(
        'BOSS!',
        subtitle: '${bossType.label} · Wave $wave',
        fontSize: 60,
        color: const Color(0xFF9B59B6),
      );
      _pendingBanner = _Banner.waveIntro;
      _bannerTime = 0;
      feel.boss(AudioCues.bossIntro);
      feel.boss(
        bossType == BossType.magma ? AudioCues.magmaRoar : AudioCues.ogreRoar,
      );
      return;
    }
    _showBanner(
      'Wave $wave',
      subtitle: meta.mode == PlayMode.campaign
          ? 'Stage ${MetaState.stageOf(wave)}'
          : null,
      fontSize: 56,
      color: const Color(0xFF1A2332),
    );
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

  /// Bot tuning for kid [index] (its own Quicker pals and Faster pals).
  DifficultyTuning _allyTuning(int index) {
    return DifficultyTuning.of(Difficulty.easy, wave: wave).scaled(
      gapScale: meta.kidGapScale(index),
      chargeScale: meta.kidChargeScale(index),
    );
  }

  /// One interstitial outside the fight (see [AdPolicy]): after a boss
  /// wave clear, after a loss (once its coin beat is over), and otherwise
  /// at a wave clear or a Pause → menu once five waves have been won, all
  /// only after a won wave and three minutes of fighting since the last
  /// one. Remove Ads skips it. A missed show does not reset the counts.
  void _offerEndAd(AdMoment moment) {
    if (_adInFlight) return;
    if (adsRemoved?.call() ?? false) return;
    if (!AdPolicy.allows(
      inFight: phase == MatchPhase.fight,
      moment: moment,
      playSinceAd: Duration(milliseconds: (_playSinceAd * 1000).round()),
      wavesSinceAd: _wavesSinceAd,
    )) {
      return;
    }
    _adInFlight = true;
    unawaited(_finishAdOffer());
  }

  Future<void> _finishAdOffer() async {
    var shown = false;
    try {
      shown = await endAd.onRunEnded(fightSeconds: fightSeconds);
    } finally {
      _adInFlight = false;
      if (shown) {
        _wavesSinceAd = 0;
        _playSinceAd = 0;
      }
    }
  }

  void _payKnockouts() {
    final boss = _boss;
    if (boss != null && boss.isKo && !_bossRewarded) {
      _bossRewarded = true;
      feel.boss(
        _bossType == BossType.magma
            ? AudioCues.magmaDefeat
            : AudioCues.ogreDefeat,
      );
      feel.boss(AudioCues.bossDefeated);
      rewardRandomItems(
        BossRules.rewardItems,
        at: boss.hitCenter,
        reason: '${_bossType?.label ?? 'Boss'} beaten',
      );
    }
    var paid = 0;
    for (final kid in enemies) {
      if (!kid.isKo || !_paidKills.add(kid)) continue;
      _dropPerks(kid);
      paid += MetaState.coinsForKnockout(wave);
    }
    if (paid == 0) return;
    meta.earn(paid);
    killCoinsThisWave += paid;
  }

  /// Throw-rank hold before Easy or Normal shortens the player's bar.
  /// Bots scale from this, so their windup stays put when the bar speeds up.
  /// The selected kid's full-charge hold (its own Quicker throw ranks).
  double _baseChargeSeconds() =>
      CombatRules.playerChargeSeconds(meta.kidThrowRank(_selectedIndex));

  int get _selectedIndex {
    final kid = _selected;
    if (kid == null) return 0;
    return math.max(0, players.indexOf(kid));
  }

  double _playerChargeSeconds() =>
      _baseChargeSeconds() * _tuning().playerChargeTimeScale;

  LobProjectile? _onEnemyFire(
    KidComponent enemy,
    KidComponent? target,
    double rangeScale, {
    Vector2? aimAt,
    Sprite? sprite,
    double radiusScale = 1,
    bool quiet = false,
    bool magma = false,
  }) {
    if (phase != MatchPhase.fight || enemy.isKo) return null;
    if (!quiet) feel.enemyReleased();
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
    final shot = _spawnShot(
      owner: enemy,
      lob: lob,
      targets: players,
      sprite: sprite,
      radiusScale: radiusScale,
    );
    if (magma) _magmaShots.add(shot);
    _armRivalShot(enemy, shot);
    return shot;
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
          tuning: () => _allyTuning(i),
          initialDelay: profile.throwGap((0.35 + i * 0.2).clamp(0.0, 1.0)),
          onFire: _onAllyFire,
          isFighting: () => phase == MatchPhase.fight && !_settling,
          side: KidSide.player,
          approachColumn: 1,
          isManual: () => identical(_selected, kid),
          currentWave: () => wave,
          playerChargeSeconds: () =>
              CombatRules.playerChargeSeconds(meta.kidThrowRank(i)),
          aimJitterScale: () => meta.kidAimScale(i),
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
      speedScale: CombatRules.projectileSpeedScale(
        meta.kidThrowRank(_selectedIndex),
      ),
      originY: kid.throwOrigin.y,
      trackY: kid.hitCenter.y,
    );
    kid.showThrowPose();
    feel.playerReleased(fullPower: charge >= 0.999);
    _spawnShot(owner: kid, lob: lob, targets: enemies, manualThrow: true);
  }

  LobProjectile _spawnShot({
    required KidComponent owner,
    required RowLob lob,
    required List<KidComponent> targets,
    bool manualThrow = false,
    Sprite? sprite,
    double radiusScale = 1,
  }) {
    final fromPlayer = owner.side == KidSide.player;
    final shot = LobProjectile(
      sprite:
          sprite ?? _armedSprite(fromPlayer && manualThrow) ?? _kit.projectile,
      position: owner.throwOrigin.clone(),
      velocity: lob.velocity.clone(),
      targets: targets,
      owner: owner,
      blockedByFort: true,
      forts: _allForts,
      friendlyFortDamage: _tuning().friendlyFortDamage,
      passOwnFort: fromPlayer && meta.passesOwnFort,
      manualThrow: manualThrow,
      radius: fromPlayer
          ? MetaState.baseBlastRadius * meta.blastScale
          : MetaState.baseBlastRadius * radiusScale,
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
      shot.splat = _splatArmed;
      // The spiked bunker buster is half again as big as a snowball.
      if (_crackerArmed && _bunkerBuster != null) {
        shot.size.scale(bunkerBusterDrawScale);
      }
      _crackerArmed = false;
      _splatArmed = false;
      _powerArmed = false;
      hudRevision.value++;
    }
    world.add(shot);
    return shot;
  }

  @visibleForTesting
  void debugKidHit(LobProjectile shot, KidComponent target) =>
      _onKidHit(shot, target);

  void _onKidHit(LobProjectile shot, KidComponent target) {
    _burst(shot.position, depthY: target.hitCenter.y);
    if (phase != MatchPhase.fight || target.isKo) return;
    if (_bossShots.remove(shot)) {
      _magmaSplash(shot);
      feel.impact(meta.season);
      _bossBlast(shot.hitPosition, struck: target);
      return;
    }
    final selectedHit = identical(target, _selected);
    if (!applySnowballHit(shot: shot, target: target)) {
      feel.armorBlocked();
      return;
    }
    if (shot.splat) _splatBlast(shot, struck: target);
    if (target.isBoss) {
      final magma = _bossType == BossType.magma;
      if (!target.isKo) {
        feel.boss(magma ? AudioCues.magmaHit : AudioCues.ogreHit);
      }
      feel.impact(meta.season);
    } else {
      feel.kidHit(knockedOut: target.isKo, season: meta.season);
    }
    _magmaSplash(shot);
    target.recoil(shot.facing);
    if (target.side == KidSide.enemy) _rivalHurt(target);
    if (target.isKo && target.side == KidSide.enemy) _creditKo(shot.owner);
    _punch(knockedOut: target.isKo);
    if (target.isKo && target.side == KidSide.enemy) {
      world.add(
        CoinPop(
          amount: MetaState.coinsForKnockout(wave),
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
    if (!ally && _rivalArmorTime > 0) return false; // a rival's team armor
    final hits = fromPlayer
        ? meta.kidHits(math.max(0, players.indexOf(owner)))
        : 1;
    var scale = ally
        ? meta.kidPoise(math.max(0, players.indexOf(target)))
        : meta.stunScaleFor(ally: false);
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
    if (shot.cracker && cover.side != shot.owner?.side) {
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

  @visibleForTesting
  void debugGroundMiss(LobProjectile shot) => _onGroundMiss(shot);

  @visibleForTesting
  void debugBossBlast(Vector2 at) => _bossBlast(at);

  void _onGroundMiss(LobProjectile shot) {
    _burst(shot.position, power: 0.6);
    feel.impact(meta.season);
    _magmaSplash(shot);
    if (phase != MatchPhase.fight) return;
    if (_bossShots.remove(shot)) _bossBlast(shot.hitPosition);
    if (shot.splat) _splatBlast(shot);
  }

  /// A magma ball lands with its own lava-and-steam splash.
  void _magmaSplash(LobProjectile shot) {
    if (!_magmaShots.remove(shot)) return;
    final splash = _magmaImpact;
    if (splash != null) {
      world.add(ImpactBurst(sprite: splash, position: shot.position.clone()));
    }
    feel.boss(AudioCues.magmaImpact);
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
    if (phase == MatchPhase.fight) {
      fightSeconds += dt;
      _playSinceAd += dt;
    }
    if (_settling) {
      _settleTime += dt;
      if (!_shotsInFlight || _settleTime >= settleCapSeconds) {
        resolveKnockouts();
      }
    }
    _tickHound(dt);
    if (_clearWaitsOnHound && !houndInPlay) resolveKnockouts();
    _tickWalkOns(dt);
    _tickPerks(dt);
    if (_armorTime > 0) {
      _armorTime -= dt;
      if (_armorTime <= 0) {
        for (final kid in players) {
          kid.armored = false;
        }
        hudRevision.value++;
      }
    }
    if (_freezeTime > 0) {
      _freezeTime -= dt;
      if (_freezeTime <= 0) {
        _freezeTime = 0;
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

/// A one-shot picture that grows a little and fades (the ogre's slam ring).
class _FadingSprite extends SpriteComponent {
  _FadingSprite({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.seconds,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: ArenaGrid.depthOrder(position.y) + 3,
       );

  final double seconds;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    final t = (_age / seconds).clamp(0.0, 1.0);
    scale.setAll(0.7 + 0.5 * t);
    opacity = 1 - t;
    if (_age >= seconds) removeFromParent();
  }
}
