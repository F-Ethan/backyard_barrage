import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../meta/difficulty.dart';
import '../arena_grid.dart';
import '../combat_rules.dart';
import '../enemy_ai.dart';
import 'kid_component.dart';

typedef EnemyFire =
    void Function(KidComponent enemy, KidComponent? target, double rangeScale);

enum _AiPhase { wait, step, telegraph }

/// Telegraph a lob, then throw. Movement is one grid step every few throws.
class EnemyController extends Component {
  EnemyController({
    required this.host,
    required this.players,
    required this.wave,
    required this.rng,
    required this.onFire,
    required this.isFighting,
    required this.tuning,
    required double initialDelay,
  }) : _cycle = initialDelay;

  final KidComponent host;
  final List<KidComponent> players;
  final int wave;
  final math.Random rng;
  final EnemyFire onFire;
  final bool Function() isFighting;
  final DifficultyTuning Function() tuning;

  _AiPhase _phase = _AiPhase.wait;
  double _cycle;
  double _elapsed = 0;
  int _throws = 0;
  Vector2? _moveTarget;

  double get _telegraph {
    final window = _cycle * 0.28;
    if (window < 0.3) return 0.3;
    if (window > 0.55) return 0.55;
    return window;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isFighting() || host.isKo) {
      host.setWalking(false);
      host.clearChargePose();
      return;
    }
    if (host.isFlinching) return;

    _elapsed += dt;
    if (_phase == _AiPhase.step) {
      _tickStep(dt);
      if (_phase == _AiPhase.step) return;
    }

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

  void _fire() {
    final cell = ArenaGrid.nearestCell(KidSide.enemy, host.position);
    final index = EnemyAi.pickLaneTarget(
      [for (final kid in players) !kid.isKo],
      [
        for (final kid in players)
          ArenaGrid.nearestCell(kid.side, kid.position).row,
      ],
      cell.row,
      rng,
    );
    final target = index == null ? null : players[index];
    final scatter = EnemyAi.rangeScatter(
      rng,
      CombatRules.enemyAimJitterRadians(wave),
    );
    host.showThrowPose();
    onFire(host, target, scatter);
    _throws += 1;
    _beginCycle();
  }

  void _beginCycle() {
    final profile = tuning();
    _cycle = EnemyAi.throwGap(rng, profile);
    _elapsed = 0;
    _phase = _AiPhase.wait;
    _moveTarget = null;
    host.clearChargePose();
    if (!EnemyAi.shouldGridStep(_throws, profile.throwsPerStep)) return;
    final nudge = EnemyAi.gridStep(rng);
    final cell = ArenaGrid.nearestCell(KidSide.enemy, host.position);
    final next = ArenaGrid.clampCell(
      cell.column + nudge.column,
      cell.row + nudge.row,
    );
    final dest = ArenaGrid.cellCenter(KidSide.enemy, next.column, next.row);
    if (dest.distanceTo(host.position) < 1) return;
    _moveTarget = dest;
    _phase = _AiPhase.step;
    host.setWalking(true);
  }
}
