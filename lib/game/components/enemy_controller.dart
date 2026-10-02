import 'dart:math' as math;

import 'package:flame/components.dart';

import '../arena_grid.dart';
import '../combat_rules.dart';
import '../enemy_ai.dart';
import '../throw_physics.dart';
import 'kid_component.dart';

typedef EnemyFire =
    void Function(KidComponent enemy, Vector2 aim, double charge);

enum _AiPhase { wait, sidestep, charge, recover }

/// Charge, jittered aim, and a grid step that prefers rows over columns.
class EnemyController extends Component {
  EnemyController({
    required this.host,
    required this.players,
    required this.wave,
    required this.rng,
    required this.onFire,
    required this.isFighting,
    required double initialDelay,
    this.moveSpeed = 0,
  }) : _timer = initialDelay;

  final KidComponent host;
  final List<KidComponent> players;
  final int wave;
  final math.Random rng;
  final EnemyFire onFire;
  final bool Function() isFighting;
  final double moveSpeed;

  _AiPhase _phase = _AiPhase.wait;
  double _timer;
  double _charge = 0;
  Vector2? _moveTarget;
  Vector2 _aim = Vector2(-1, -0.4);

  double get _speed {
    if (moveSpeed > 0) return moveSpeed;
    return ThrowPhysics.kidMoveSpeed();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isFighting()) {
      host.setWalking(false);
      host.clearChargePose();
      return;
    }
    if (host.isKo) {
      host.setWalking(false);
      host.clearChargePose();
      return;
    }
    if (host.isFlinching) return;

    switch (_phase) {
      case _AiPhase.wait:
      case _AiPhase.recover:
        _timer -= dt;
        if (_timer <= 0) _beginAct();
      case _AiPhase.sidestep:
        final target = _moveTarget;
        if (target == null) {
          host.setWalking(false);
          _beginCharge();
          break;
        }
        final delta = target - host.position;
        final distance = delta.length;
        final step = _speed * dt;
        if (distance <= step || distance < 1) {
          host.position = target.clone();
          host.setWalking(false);
          _beginCharge();
        } else {
          host.position += delta / distance * step;
          host.setWalking(true);
        }
      case _AiPhase.charge:
        final duration = CombatRules.enemyChargeSeconds(wave);
        _charge = (_charge + dt / duration).clamp(0.0, 1.0);
        host.showChargePose();
        if (_charge >= 1) {
          host.showThrowPose();
          onFire(host, _aim, _charge);
          _phase = _AiPhase.recover;
          _timer = 0.55 + rng.nextDouble() * 0.7;
          _charge = 0;
        }
    }
  }

  void _beginAct() {
    final nudge = EnemyAi.gridNudge(rng);
    if (nudge.column == 0 && nudge.row == 0) {
      _beginCharge();
      return;
    }
    final cell = ArenaGrid.nearestCell(KidSide.enemy, host.position);
    final next = ArenaGrid.clampCell(
      cell.column + nudge.column,
      cell.row + nudge.row,
    );
    _moveTarget = ArenaGrid.cellCenter(KidSide.enemy, next.column, next.row);
    _phase = _AiPhase.sidestep;
    host.setWalking(true);
  }

  void _beginCharge() {
    final index = EnemyAi.pickLivingIndex([
      for (final kid in players) !kid.isKo,
    ], rng);
    if (index == null) {
      _phase = _AiPhase.recover;
      _timer = 0.4;
      host.clearChargePose();
      return;
    }
    final target = players[index];
    final aim = ThrowPhysics.defaultAim(host.throwOrigin, target.hitCenter);
    _aim = EnemyAi.jitterAim(aim, rng, CombatRules.enemyAimJitterRadians(wave));
    _charge = 0;
    _phase = _AiPhase.charge;
    host.showChargePose();
  }
}
