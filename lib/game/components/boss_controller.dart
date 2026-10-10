import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../meta/difficulty.dart';
import '../arena_grid.dart';
import '../boss.dart';
import 'kid_component.dart';

/// What a boss is doing.
enum BossPhase {
  /// Standing or walking to its next row.
  roam,

  /// Holding its throw pose before a lob.
  windup,

  /// Magma: leaning back, glowing, with the wave's path marked.
  waveWindup,

  /// Magma: both arms pushed out as the wave leaves.
  wavePush,

  /// Ogre: crouched before the hop.
  hopCrouch,

  /// Ogre: in the air.
  hopAir,

  /// Ogre: landed hard; the ice spikes are on their way.
  crash,
}

/// A boss's brain: it walks between rows on its home column, lobs on a
/// timer, and every so often does its special. Each special has a long,
/// readable windup so the crew can get out of the way.
class BossController extends Component {
  BossController({
    required this.host,
    required this.type,
    required this.players,
    required this.rng,
    required this.difficulty,
    required this.isFighting,
    required this.specialSprites,
    required this.onThrow,
    required this.onWaveWindup,
    required this.onWave,
    required this.onHop,
    required this.onSlam,
  }) : _throwIn = BossRules.throwGap(difficulty) * 0.6,
       _specialIn = BossRules.specialGap(difficulty) * 0.6;

  final KidComponent host;
  final BossType type;
  final List<KidComponent> players;
  final math.Random rng;
  final Difficulty difficulty;
  final bool Function() isFighting;

  /// Special-move frames, from [BossArt.specials] in order.
  final List<Sprite> specialSprites;

  /// Lob at [target], aimed at [aim].
  final void Function(KidComponent boss, KidComponent target, Vector2 aim)
  onThrow;

  /// Magma: the wave's lane is about to fire. Mark it on the ground.
  final void Function(KidComponent boss, double laneY) onWaveWindup;

  /// Magma: send the heat wave down [laneY].
  final void Function(KidComponent boss, double laneY) onWave;

  /// Ogre: it leaves the ground.
  final void Function(KidComponent boss) onHop;

  /// Ogre: it lands. Ice spikes start cracking under the crew.
  final void Function(KidComponent boss) onSlam;

  /// Column the boss works on: the back line for the magma elemental, one
  /// step in for the ogre.
  int get homeColumn => switch (type) {
    BossType.magma => ArenaGrid.columnsPerSide - 1,
    BossType.ogre => ArenaGrid.columnsPerSide - 2,
  };

  double get walkSpeed => switch (type) {
    BossType.magma => 60,
    BossType.ogre => 90,
  };

  /// Seconds in the throw pose before a lob.
  static const double throwWindupSeconds = 0.7;

  static const double pushSeconds = 0.45;
  static const double crashSeconds = 0.45;

  BossPhase _phase = BossPhase.roam;
  double _clock = 0;
  double _throwIn;
  double _specialIn;
  bool _specialPending = false;
  KidComponent? _target;
  Vector2? _aim;
  Vector2? _moveTo;
  double _laneY = 0;

  BossPhase get phase => _phase;

  @visibleForTesting
  void forceSpecial() {
    _specialIn = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (host.isKo) {
      host.lift = 0;
      return;
    }
    if (!isFighting() || host.isStunned) {
      host.setWalking(false);
      return;
    }
    _clock += dt;
    switch (_phase) {
      case BossPhase.roam:
        _roam(dt);
      case BossPhase.windup:
        if (_clock >= throwWindupSeconds) _release();
      case BossPhase.waveWindup:
        if (_clock >= BossRules.waveWindupSeconds) {
          _go(BossPhase.wavePush, sprite: specialSprites[1]);
          onWave(host, _laneY);
        }
      case BossPhase.wavePush:
        if (_clock >= pushSeconds) _endSpecial();
      case BossPhase.hopCrouch:
        if (_clock >= BossRules.hopCrouchSeconds) {
          _go(BossPhase.hopAir, sprite: specialSprites[1]);
          onHop(host);
        }
      case BossPhase.hopAir:
        final t = (_clock / BossRules.hopAirSeconds).clamp(0.0, 1.0);
        host.lift = BossRules.hopHeight * math.sin(math.pi * t);
        if (_clock >= BossRules.hopAirSeconds) {
          host.lift = 0;
          _go(BossPhase.crash, sprite: specialSprites[2]);
          onSlam(host);
        }
      case BossPhase.crash:
        if (_clock >= crashSeconds) _endSpecial();
    }
  }

  void _roam(double dt) {
    _throwIn -= dt;
    _specialIn -= dt;
    if (_specialIn <= 0 && !_specialPending) {
      _specialPending = true;
      // Line up with someone first: the wave runs along the boss's row.
      final target = _livingTarget();
      if (target != null && type == BossType.magma) {
        _moveTo = _homeCell(_rowOf(target));
      }
    }
    final dest = _moveTo;
    if (dest != null) {
      final delta = dest - host.position;
      final step = walkSpeed * dt;
      if (delta.length <= step) {
        host.position.setFrom(dest);
        _moveTo = null;
        host.setWalking(false);
      } else {
        host.position.add(delta.normalized() * step);
        host.setWalking(true);
      }
      host.syncDepth();
      if (_moveTo != null) return;
    }
    if (_specialPending) {
      _startSpecial();
      return;
    }
    if (_throwIn <= 0) {
      _startThrow();
      return;
    }
    if (rng.nextDouble() < dt * 0.25) {
      final target = _livingTarget();
      if (target != null) _moveTo = _homeCell(_rowOf(target));
    }
  }

  void _startThrow() {
    final target = _livingTarget();
    if (target == null) {
      _throwIn = 0.5;
      return;
    }
    _target = target;
    final spread =
        DifficultyTuning.of(difficulty).aimDepthRows * ArenaGrid.rowStep;
    final error = (rng.nextDouble() + rng.nextDouble() - 1) * spread;
    _aim = target.hitCenter + Vector2(0, error);
    host.showChargePose();
    _go(BossPhase.windup);
  }

  void _release() {
    final target = _target;
    final aim = _aim;
    host.clearChargePose();
    if (target != null && aim != null && !target.isKo) {
      host.showThrowPose();
      onThrow(host, target, aim);
    }
    _target = null;
    _aim = null;
    _throwIn = BossRules.throwGap(difficulty) * (0.8 + rng.nextDouble() * 0.4);
    _go(BossPhase.roam);
  }

  void _startSpecial() {
    _specialPending = false;
    switch (type) {
      case BossType.magma:
        _laneY = host.position.y - ArenaGrid.bodyLift;
        _go(BossPhase.waveWindup, sprite: specialSprites[0]);
        onWaveWindup(host, _laneY);
      case BossType.ogre:
        _go(BossPhase.hopCrouch, sprite: specialSprites[0]);
    }
  }

  void _endSpecial() {
    host.lift = 0;
    host.posedOverride = null;
    _specialIn =
        BossRules.specialGap(difficulty) * (0.85 + rng.nextDouble() * 0.3);
    _throwIn = math.max(_throwIn, 0.8);
    _go(BossPhase.roam);
  }

  void _go(BossPhase next, {Sprite? sprite}) {
    _phase = next;
    _clock = 0;
    if (sprite != null) host.posedOverride = sprite;
  }

  KidComponent? _livingTarget() {
    final living = [
      for (final kid in players)
        if (!kid.isKo) kid,
    ];
    if (living.isEmpty) return null;
    return living[rng.nextInt(living.length)];
  }

  int _rowOf(KidComponent kid) =>
      ArenaGrid.nearestCell(kid.side, kid.position).row;

  Vector2 _homeCell(int row) =>
      ArenaGrid.cellCenter(KidSide.enemy, homeColumn, row);
}
