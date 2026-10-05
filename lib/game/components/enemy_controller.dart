import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../meta/difficulty.dart';
import '../arena_grid.dart';
import '../combat_rules.dart';
import '../enemy_ai.dart';
import '../throw_physics.dart';
import 'kid_component.dart';

typedef EnemyFire =
    void Function(KidComponent enemy, KidComponent? target, double rangeScale);

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

  /// The player's full-charge time. Easy and Normal scale their windup
  /// from this. Hard ignores it and keeps the short windup.
  final double Function()? playerChargeSeconds;

  _AiPhase _phase = _AiPhase.wait;
  double _cycle;
  double _elapsed = 0;
  int _throws = 0;
  int _seenHp;
  int _retreats = 0;
  Vector2? _moveTarget;

  double get _telegraph {
    final player =
        playerChargeSeconds?.call() ?? CombatRules.playerChargeSeconds(0);
    return tuning().botChargeSeconds(player);
  }

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
    }
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
    final speed = tuning().enemyStepSpeed;
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

  void _fire() {
    final cell = ArenaGrid.nearestCell(side, host.position);
    final rows = [
      for (final kid in players)
        ArenaGrid.nearestCell(kid.side, kid.position).row,
    ];
    final living = [for (final kid in players) !kid.isKo];
    final index = EnemyAi.pickLaneTarget(living, rows, cell.row, rng);
    final target = index == null ? null : players[index];
    final scatter = EnemyAi.rangeScatter(
      rng,
      CombatRules.enemyAimJitterRadians(currentWave?.call() ?? wave),
    );
    var fellShort = false;
    if (target != null) {
      final distance = (host.throwOrigin.x - target.hitCenter.x).abs();
      fellShort = !ThrowPhysics.enemyLobReaches(
        distance: distance,
        rangeScale: scatter,
      );
    }
    host.showThrowPose();
    onFire(host, target, scatter);
    _throws += 1;
    _beginCycle(shotFellShort: fellShort);
  }

  void _beginCycle({required bool shotFellShort}) {
    final profile = tuning();
    _cycle = EnemyAi.throwGap(rng, profile);
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
    return EnemyAi.planBotStep(
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
