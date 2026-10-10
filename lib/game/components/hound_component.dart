import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../meta/difficulty.dart';
import '../../seasons/season.dart';
import '../arena_grid.dart';
import 'kid_component.dart';

/// Frames for the Ice hound. All face screen-left, toward the player crew.
class HoundSprites {
  const HoundSprites({
    required this.idle,
    required this.run,
    required this.crouch,
    required this.leap,
    required this.bite,
    required this.land,
    required this.hit,
  });

  final Sprite idle;

  /// Gallop cycle.
  final List<Sprite> run;
  final Sprite crouch;
  final Sprite leap;

  /// Snarl, then a puff of frost breath.
  final List<Sprite> bite;

  /// Touching down after the river leap.
  final Sprite land;

  /// Flinching from a snowball, before it runs off.
  final Sprite hit;
}

enum HoundState { warn, approach, jump, hunt, pounce, bite, leave, flee, gone }

/// A rare yard event: an ice hound that runs in from the rival side along
/// one lane, leaps the river, and goes for the player crew.
///
/// It stands at the right edge first with a frosty line along its lane, so
/// the player can step out of the way. On the player's side, a kid inside
/// its catch box (wider on harder difficulties) is caught: it pounces and
/// bites, and that kid is knocked out in one go on every difficulty. A
/// snowball hit before it lands (the leap over the river included) scares
/// it back off the yard.
/// Kid-safe: the bite is a cartoon frost snap; the kid is frozen out of the
/// round like any other knockout.
class HoundComponent extends SpriteComponent {
  HoundComponent({
    required this.sprites,
    required this.laneY,
    required this.players,
    required this.onCatch,
    required this.isLive,
    required this.difficulty,
    this.onState,
  }) : super(
         sprite: sprites.run.first,
         size: Vector2.all(drawSize),
         anchor: Anchor.bottomCenter,
         position: Vector2(entryX, laneY),
       ) {
    _syncDepth();
  }

  final HoundSprites sprites;

  /// Feet height of the lane it runs along.
  final double laneY;
  final List<KidComponent> players;

  /// Called when the bite lands on [kid]. Return false to bounce off (for
  /// example, Frost armor), which sends the hound away.
  final bool Function(KidComponent kid) onCatch;

  /// False outside a live fight; the hound stops catching.
  final bool Function() isLive;
  final Difficulty difficulty;

  /// Called on each state change (for sound).
  final void Function(HoundState state)? onState;

  /// Art frame names under the hellhound folder.
  static const frames = [
    'idle',
    'run_00',
    'run_01',
    'run_02',
    'run_03',
    'jump_00',
    'jump_01',
    'bite_00',
    'bite_01',
    'land',
    'hit',
  ];

  static String framePath(String frame) =>
      '${SeasonAssets.rivalDir}hellhound/hellhound_${frame}_draft.png';

  static const double drawSize = 200;
  static const double entryX = 1280 + 120;
  static const double standX = 1280 - 70;
  static const double entrySpeed = 320;
  static const double runSpeed = 520;
  static const double warnSeconds = 1;
  static const double frameSeconds = 0.08;

  /// Leap timing: crouch, then airborne across the river, then land.
  static const double crouchSeconds = 0.12;
  static const double airSeconds = 0.5;
  static const double landSeconds = 0.1;

  /// Peak height of the leap, in pixels above the lane.
  static const double leapHeight = 90;

  /// How long it flinches from a snowball before running off.
  static const double flinchSeconds = 0.25;

  /// Waves before this one never get a hound.
  static const int firstWave = 3;

  /// Chance a wave (from [firstWave]) gets a hound.
  static double chanceFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 0.12,
    Difficulty.normal => 0.18,
    Difficulty.hard => 0.25,
  };

  /// From this wave a hound is likelier ([bracketChance]).
  static const int likelyWave = 5;

  /// From this wave every wave has a hound, plus one more sure hound every
  /// ten waves after (wave 20 has two, wave 30 three).
  static const int packWave = 10;

  /// Chance of a hound on waves [likelyWave] to [packWave] - 1.
  static double bracketChance(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 0.5,
    Difficulty.normal => 0.6,
    Difficulty.hard => 0.7,
  };

  /// From [packWave]: chance of one more hound on top of the sure ones.
  static double extraChance(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 0.2,
    Difficulty.normal => 0.25,
    Difficulty.hard => 0.3,
  };

  /// The rolled hounds come early, so even a quick wave meets them: the
  /// first [firstEarliest]–[firstLatest]s in, the next ones 4–8s apart.
  static const double firstEarliest = 4;
  static const double firstLatest = 10;

  /// A wave that drags on gets more: one extra hound somewhere in each
  /// [lingerWindow] after the first [lingerStart]s (so by 5 minutes a
  /// second, by 15 minutes up to [maxPerWave]).
  static const double lingerStart = 60;
  static const double lingerWindow = 300;

  /// Most hounds in one wave.
  static const int maxPerWave = 4;

  /// Earliest any hound comes, in seconds into the fight.
  static const double earliest = firstEarliest;

  /// Hounds rolled for [wave] at the start, ignoring how long it lasts.
  static int rolledFor(int wave, Difficulty difficulty, math.Random rng) {
    if (wave < firstWave) return 0;
    if (wave < likelyWave) {
      return rng.nextDouble() < chanceFor(difficulty) ? 1 : 0;
    }
    if (wave < packWave) {
      return rng.nextDouble() < bracketChance(difficulty) ? 1 : 0;
    }
    final sure = wave ~/ packWave;
    final extra = rng.nextDouble() < extraChance(difficulty) ? 1 : 0;
    return math.min(maxPerWave, sure + extra);
  }

  /// When this wave's hounds come, in seconds into the fight, sorted.
  ///
  /// Two programs:
  /// * The roll ([rolledFor]): a fixed chance per wave (wave 6 on Easy is
  ///   50%), arriving early so the wave's length does not matter.
  /// * Lingering: from wave [firstWave], one more hound in each
  ///   [lingerWindow] after [lingerStart], so a long fight keeps meeting
  ///   them, up to [maxPerWave] in all. A hound whose time the fight never
  ///   reaches does not come.
  static List<double> scheduleFor({
    required int wave,
    required Difficulty difficulty,
    required math.Random rng,
  }) {
    if (wave < firstWave) return const [];
    double between(double a, double b) => a + rng.nextDouble() * (b - a);
    final times = <double>[];
    var at = between(firstEarliest, firstLatest);
    for (var i = rolledFor(wave, difficulty, rng); i > 0; i--) {
      times.add(at);
      at += between(4, 8);
    }
    for (var k = 0; times.length < maxPerWave; k++) {
      final from = lingerStart + k * lingerWindow;
      times.add(between(from, from + lingerWindow - lingerStart));
    }
    times.sort();
    return times;
  }

  /// Catch box: how far off its lane (feet Y, in rows) a kid is still in
  /// its path, and how far ahead it pounces from. Larger on harder modes.
  static double laneHalfRows(Difficulty d) => switch (d) {
    Difficulty.easy => 0.45,
    Difficulty.normal => 0.7,
    Difficulty.hard => 1.0,
  };

  static double pounceReach(Difficulty d) => switch (d) {
    Difficulty.easy => 90,
    Difficulty.normal => 120,
    Difficulty.hard => 160,
  };

  double get laneHalf => ArenaGrid.rowStep * laneHalfRows(difficulty);

  /// Where it leaves the ground (past the right bank) and lands (past the
  /// left bank) on its lane.
  double get takeoffX => ArenaGrid.riverRightX(laneY) + 50;
  double get landingX => ArenaGrid.riverLeftX(laneY) - 50;

  HoundState _state = HoundState.warn;
  double _clock = 0;
  double _warned = 0;
  KidComponent? _prey;
  double _pounceFromX = 0;

  /// Height above the lane while airborne (drawn only).
  double _lift = 0;

  HoundState get state => _state;

  /// Body point snowballs test against.
  Vector2 get hitCenter => position + Vector2(0, -size.y * 0.3 - _lift);
  static const double hitRadius = 55;

  /// Where a snowball's ground track has to pass to hit it: under its
  /// body, even mid-leap (the lob's shadow lines up with the hound's).
  Vector2 get groundHitCenter => position + Vector2(0, -size.y * 0.3);

  /// True while a snowball can still turn it around: until it has landed
  /// on the player's side, so the leap over the river counts.
  bool get scareable =>
      _state == HoundState.warn ||
      _state == HoundState.approach ||
      _state == HoundState.jump;

  /// A snowball hit: turn tail and run back off the yard.
  void scare() {
    if (!scareable) return;
    _go(HoundState.flee);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    switch (_state) {
      case HoundState.warn:
        if (position.x > standX) {
          position.x = math.max(standX, position.x - entrySpeed * dt);
          _cycleRun();
        } else {
          sprite = sprites.idle;
          _warned += dt;
          if (_warned >= warnSeconds) _go(HoundState.approach);
        }
      case HoundState.approach:
        position.x -= runSpeed * dt;
        _cycleRun();
        if (position.x <= takeoffX) {
          position.x = takeoffX;
          _go(HoundState.jump);
        }
      case HoundState.jump:
        _stepJump();
      case HoundState.hunt:
        position.x -= runSpeed * dt;
        _cycleRun();
        if (isLive()) _lookForPrey();
        if (position.x < -150) _go(HoundState.gone);
      case HoundState.pounce:
        final prey = _prey!;
        const air = 0.16;
        sprite = sprites.leap;
        final t = (_clock / air).clamp(0.0, 1.0);
        position.x = _pounceFromX + (prey.position.x + 30 - _pounceFromX) * t;
        _lift = 40 * math.sin(math.pi * t);
        if (_clock >= air) {
          _lift = 0;
          _go(HoundState.bite);
          sprite = sprites.bite.first;
          if (!isLive() || prey.isKo || !onCatch(prey)) {
            _go(HoundState.flee);
          }
        }
      case HoundState.bite:
        sprite = _clock < 0.15 ? sprites.bite.first : sprites.bite.last;
        if (_clock >= 0.5) _go(HoundState.leave);
      case HoundState.leave:
        position.x -= runSpeed * dt;
        _cycleRun();
        if (position.x < -150) _go(HoundState.gone);
      case HoundState.flee:
        _lift = 0;
        if (_clock < flinchSeconds) {
          sprite = sprites.hit;
          break;
        }
        position.x += runSpeed * dt;
        _cycleRun();
        if (position.x > entryX + 40) _go(HoundState.gone);
      case HoundState.gone:
        removeFromParent();
    }
  }

  void _stepJump() {
    if (_clock < crouchSeconds) {
      sprite = sprites.crouch;
      return;
    }
    final air = _clock - crouchSeconds;
    if (air < airSeconds) {
      final t = air / airSeconds;
      sprite = sprites.leap;
      position.x = takeoffX + (landingX - takeoffX) * t;
      _lift = leapHeight * math.sin(math.pi * t);
      return;
    }
    _lift = 0;
    position.x = landingX;
    sprite = sprites.land;
    if (air >= airSeconds + landSeconds) _go(HoundState.hunt);
  }

  void _go(HoundState next) {
    _state = next;
    _clock = 0;
    onState?.call(next);
  }

  void _cycleRun() {
    final frame = (_clock / frameSeconds).floor() % sprites.run.length;
    sprite = sprites.run[frame];
  }

  void _lookForPrey() {
    final reach = pounceReach(difficulty);
    for (final kid in players) {
      if (kid.isKo) continue;
      if ((kid.position.y - laneY).abs() > laneHalf) continue;
      final ahead = position.x - kid.position.x;
      if (ahead < -20 || ahead > reach) continue;
      _prey = kid;
      _pounceFromX = position.x;
      _go(HoundState.pounce);
      return;
    }
  }

  void _syncDepth() {
    priority = ArenaGrid.depthOrder(laneY - ArenaGrid.bodyLift);
    final f = ArenaGrid.depthScale(laneY, groundTrack: false);
    scale.setValues(f, f);
  }

  @override
  void render(Canvas canvas) {
    if (_state == HoundState.warn) _renderLaneWarning(canvas);
    final sy = scale.y == 0 ? 1.0 : scale.y;
    canvas.save();
    if (_lift > 0) canvas.translate(0, -_lift / sy);
    if (_state == HoundState.flee && _clock >= flinchSeconds) {
      // Running back the way it came: flip about the body.
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    super.render(canvas);
    canvas.restore();
  }

  /// A frosty dashed line along the lane, from the hound to the yard's left
  /// edge, so the player sees where it will run.
  void _renderLaneWarning(Canvas canvas) {
    final sx = scale.x == 0 ? 1.0 : scale.x;
    final feetY = size.y;
    final toLeft = position.x / sx;
    final pulse = 0.55 + 0.45 * math.sin(_clock * 12);
    final paint = Paint()
      ..color = Color.fromRGBO(159, 227, 255, 0.85 * pulse)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var d = 40.0; d < toLeft; d += 34) {
      final x = size.x / 2 - d;
      canvas.drawLine(Offset(x, feetY), Offset(x - 18, feetY), paint);
    }
  }
}
