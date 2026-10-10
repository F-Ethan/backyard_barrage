import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../meta/difficulty.dart';
import '../arena_grid.dart';
import '../combat_rules.dart';
import '../enemy_ai.dart';
import '../rival_type.dart';
import '../throw_physics.dart';
import 'kid_component.dart';

/// [aimAt] is the body-height point the bot locked onto when its windup
/// began. Null throws at the target's current spot.
typedef EnemyFire =
    void Function(
      KidComponent enemy,
      KidComponent? target,
      double rangeScale, {
      Vector2? aimAt,
    });

enum _AiPhase { wait, step, telegraph }

/// Telegraph a lob, then throw. After each throw, step toward a lane,
/// closer when the lob falls short, and back when hit.
class EnemyController extends Component {
  EnemyController({
    required this.host,
    required this.players,
    required this.rivals,
    required this.wave,
    required this.rng,
    required this.onFire,
    required this.isFighting,
    required this.tuning,
    required double initialDelay,
    this.side = KidSide.enemy,
    this.approachColumn = -1,
    this.isManual,
    this.currentWave,
    this.playerChargeSeconds,
    this.aimJitterScale,
    this.profile = const RivalProfile(),
    this.onWindup,
  }) : _cycle = initialDelay,
       _seenHp = host.hp;

  final KidComponent host;
  final List<KidComponent> players;
  final List<KidComponent> rivals;
  final int wave;
  final math.Random rng;
  final EnemyFire onFire;
  final bool Function() isFighting;
  final DifficultyTuning Function() tuning;

  /// Which half this kid steps on. Rivals use the enemy half.
  final KidSide side;

  /// Column delta that moves closer to the other team. Rivals use -1.
  final int approachColumn;

  /// When true, the player is driving this kid. The brain waits.
  final bool Function()? isManual;

  /// Live wave, for kids who stay across waves. Falls back to [wave].
  final int Function()? currentWave;

  /// Unscaled throw-rank charge. Easy and Normal speed up the player's bar
  /// only, so this stays the old hold: about 4.5s on Easy and 3s on Normal
  /// at rank 0. Hard follows it a little, about 0.45s down to 0.3s.
  final double Function()? playerChargeSeconds;

  /// Multiplier on aim scatter. Teammate aim nodes pass a value under 1.
  final double Function()? aimJitterScale;

  /// What kind of rival this is: pace, accuracy, and home column.
  final RivalProfile profile;

  /// Called as each windup starts (the frost kid glint sound).
  final void Function()? onWindup;

  _AiPhase _phase = _AiPhase.wait;
  double _cycle;
  double _elapsed = 0;
  int _throws = 0;
  int _seenHp;
  int _retreats = 0;
  Vector2? _moveTarget;

  /// Locked when the windup starts: who and where this throw goes.
  KidComponent? _lockedTarget;
  Vector2? _lockedAim;

  /// True once this windup's one re-aim ([RivalProfile.reaimAt]) is spent.
  bool _reaimed = false;

  double get _telegraph {
    final player =
        playerChargeSeconds?.call() ?? CombatRules.playerChargeSeconds(0);
    return tuning().botChargeSeconds(player) * profile.windupScale;
  }

  /// Charge pose before a bot releases. Tests check Easy and Normal stay
  /// on the unscaled hold.
  double get windupSeconds => _telegraph;

  @override
  void update(double dt) {
    super.update(dt);
    _watchHp();
    if (isManual?.call() ?? false) {
      if (_phase != _AiPhase.wait || _moveTarget != null) {
        _moveTarget = null;
        _phase = _AiPhase.wait;
        _elapsed = 0;
        host.setWalking(false);
        host.clearChargePose();
      }
      return;
    }
    if (!isFighting() || host.isKo) {
      host.setWalking(false);
      host.clearChargePose();
      _retreats = 0;
      return;
    }
    if (host.isStunned) {
      host.setWalking(false);
      return;
    }

    _elapsed += dt;
    if (_phase == _AiPhase.step) {
      _tickStep(dt);
      if (_phase == _AiPhase.step) return;
    }
    _maybeRetreat();
    if (_phase == _AiPhase.step) return;

    final telegraphAt = _cycle - _telegraph;
    if (_phase == _AiPhase.wait && _elapsed >= telegraphAt) {
      _phase = _AiPhase.telegraph;
      host.showChargePose();
      onWindup?.call();
      _lockAim();
    }
    final reaim = profile.reaimAt;
    if (_phase == _AiPhase.telegraph &&
        reaim != null &&
        !_reaimed &&
        _elapsed >= telegraphAt + _telegraph * reaim) {
      _reaimed = true;
      _reaim();
    }
    if (_phase == _AiPhase.telegraph) _lookDuringWindup();
    if (_phase == _AiPhase.telegraph && _elapsed >= _cycle) {
      _fire();
    }
  }

  void _tickStep(double dt) {
    final target = _moveTarget;
    if (target == null) {
      host.setWalking(false);
      _phase = _AiPhase.wait;
      return;
    }
    final speed = tuning().enemyStepSpeed * profile.stepScale;
    final delta = target - host.position;
    final distance = delta.length;
    final step = speed * dt;
    if (distance <= step || distance < 1) {
      host.position = target.clone();
      host.setWalking(false);
      _moveTarget = null;
      _phase = _AiPhase.wait;
      return;
    }
    host.position += delta / distance * step;
    host.setWalking(true);
  }

  void _watchHp() {
    if (host.hp < _seenHp && host.hp > 0) {
      _retreats += _seenHp - host.hp;
    }
    _seenHp = host.hp;
  }

  void _maybeRetreat() {
    if (_retreats <= 0 || _phase == _AiPhase.telegraph) return;
    if (_phase == _AiPhase.step) return;
    final next = _plan(retreat: true, shotFellShort: false);
    if (next == null) {
      _retreats = 0;
      return;
    }
    _retreats -= 1;
    _applyStep(next);
  }

  /// Teammates turn their head and body like the player's sweep while they
  /// wind up: a look up and down the yard that settles on their locked aim
  /// by the release. Rival art has no separate turn frames, so only the
  /// player's side does this.
  void _lookDuringWindup() {
    if (side != KidSide.player) return;
    final aim = _lockedAim;
    final hold = _telegraph;
    if (aim == null || hold <= 0) return;
    final start = Vector2(host.throwOrigin.x, host.hitCenter.y);
    final dx = (aim.x - start.x).abs();
    final target = dx < 1
        ? 0.0
        : math
              .atan((start.y - aim.y) / dx)
              .clamp(-ThrowPhysics.maxAimRadians, ThrowPhysics.maxAimRadians);
    final t = ((_elapsed - (_cycle - hold)) / hold).clamp(0.0, 1.0);
    // One look up and back down, fading out onto the target.
    final look =
        math.sin(2 * math.pi * t) * (1 - t) * ThrowPhysics.maxAimRadians * 0.9;
    final elevation = (target + look).clamp(
      -ThrowPhysics.maxAimRadians,
      ThrowPhysics.maxAimRadians,
    );
    host.showChargeYaw(ThrowPhysics.chargeYaw(elevation));
  }

  KidComponent? _pickTarget() {
    final cell = ArenaGrid.nearestCell(side, host.position);
    final rows = [
      for (final kid in players)
        ArenaGrid.nearestCell(kid.side, kid.position).row,
    ];
    final living = [for (final kid in players) !kid.isKo];
    final index = EnemyAi.pickLaneTarget(living, rows, cell.row, rng);
    return index == null ? null : players[index];
  }

  /// Pick the target and aim point as the windup starts. The point is where
  /// the target stands now, off by the difficulty's depth error, so a kid
  /// who moves during the windup can step out of the throw.
  void _lockAim() {
    _reaimed = false;
    final target = _pickTarget();
    _lockedTarget = target;
    if (target == null) {
      _lockedAim = null;
      return;
    }
    _lockedAim = _aimAt(target);
  }

  /// The one mid-windup look: same target, new aim point where it stands
  /// now. Moving early no longer dodges; only a late step does.
  void _reaim() {
    final target = _lockedTarget;
    if (target == null || target.isKo) return;
    _lockedAim = _aimAt(target);
  }

  @visibleForTesting
  Vector2? get lockedAim => _lockedAim;

  Vector2 _aimAt(KidComponent target) {
    final spread =
        tuning().aimDepthRows *
        profile.jitterScale *
        (aimJitterScale?.call() ?? 1) *
        ArenaGrid.rowStep;
    // Center-weighted: the sum of two uniforms.
    final error = (rng.nextDouble() + rng.nextDouble() - 1) * spread;
    return target.hitCenter + Vector2(0, error);
  }

  void _fire() {
    var target = _lockedTarget;
    var aim = _lockedAim;
    if (target == null || target.isKo) {
      // The locked kid went down during the windup; throw at someone else.
      target = _pickTarget();
      aim = target?.hitCenter.clone();
    }
    _lockedTarget = null;
    _lockedAim = null;
    final jitter =
        CombatRules.enemyAimJitterRadians(currentWave?.call() ?? wave) *
        (aimJitterScale?.call() ?? 1) *
        profile.jitterScale;
    final scatter = EnemyAi.rangeScatter(rng, jitter);
    var fellShort = false;
    if (target != null) {
      final distance = (host.throwOrigin.x - target.hitCenter.x).abs();
      fellShort = !ThrowPhysics.enemyLobReaches(
        distance: distance,
        rangeScale: scatter,
      );
    }
    host.showThrowPose();
    onFire(host, target, scatter, aimAt: aim);
    _throws += 1;
    _beginCycle(shotFellShort: fellShort);
  }

  void _beginCycle({required bool shotFellShort}) {
    final profile = tuning();
    _cycle = EnemyAi.throwGap(rng, profile) * this.profile.gapScale;
    final hold = _telegraph;
    if (hold > _cycle) _cycle = hold;
    _elapsed = 0;
    _phase = _AiPhase.wait;
    _moveTarget = null;
    host.clearChargePose();
    if (_retreats > 0) {
      final back = _plan(retreat: true, shotFellShort: false);
      if (back == null) {
        _retreats = 0;
      } else {
        _retreats -= 1;
        _applyStep(back);
        return;
      }
    }
    _applyStep(_plan(retreat: false, shotFellShort: shotFellShort));
  }

  ({int column, int row})? _plan({
    required bool retreat,
    required bool shotFellShort,
  }) {
    final profile = tuning();
    final cell = ArenaGrid.nearestCell(side, host.position);
    final home = _towardHome(cell, retreat: retreat);
    if (home != null) return home;
    final step = EnemyAi.planBotStep(
      column: cell.column,
      row: cell.row,
      playerRows: [
        for (final kid in players)
          ArenaGrid.nearestCell(kid.side, kid.position).row,
      ],
      living: [for (final kid in players) !kid.isKo],
      laneEvery: profile.throwsPerStep,
      matchPlayerRow: profile.matchPlayerRow,
      throwsCompleted: _throws,
      shotFellShort: shotFellShort,
      retreat: retreat,
      occupied: _occupied(),
      approach: approachColumn,
    );
    // A rival with a home column keeps it and only changes rows; it never
    // walks forward off the back line (or back off the front).
    final hold = this.profile.holdColumn;
    if (step == null || hold == null || retreat || cell.column != hold) {
      return step;
    }
    if (step.column == hold) return step;
    if (step.row == cell.row) return null;
    final sideways = (column: hold, row: step.row);
    for (final spot in _occupied()) {
      if (spot.column == sideways.column && spot.row == sideways.row) {
        return null;
      }
    }
    return sideways;
  }

  /// One column toward [RivalProfile.holdColumn] when this rival has one
  /// and is off it. A retreat after a hit still goes first.
  ({int column, int row})? _towardHome(
    ArenaCell cell, {
    required bool retreat,
  }) {
    final hold = profile.holdColumn;
    if (hold == null || retreat || cell.column == hold) return null;
    final next = (
      column: cell.column + (hold > cell.column ? 1 : -1),
      row: cell.row,
    );
    for (final spot in _occupied()) {
      if (spot.column == next.column && spot.row == next.row) return null;
    }
    return next;
  }

  List<({int column, int row})> _occupied() {
    final spots = <({int column, int row})>[];
    for (final kid in rivals) {
      if (identical(kid, host) || kid.isKo) continue;
      final cell = ArenaGrid.nearestCell(side, kid.position);
      spots.add((column: cell.column, row: cell.row));
    }
    return spots;
  }

  void _applyStep(({int column, int row})? next) {
    if (next == null) return;
    final dest = ArenaGrid.cellCenter(side, next.column, next.row);
    if (dest.distanceTo(host.position) < 1) return;
    _moveTarget = dest;
    _phase = _AiPhase.step;
    host.setWalking(true);
  }
}
