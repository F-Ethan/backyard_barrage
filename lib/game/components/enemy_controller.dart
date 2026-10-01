import 'dart:math' as math;

import 'package:flame/components.dart';

import '../combat_rules.dart';
import '../enemy_ai.dart';
import '../throw_physics.dart';
import 'kid_component.dart';

typedef EnemyFire = void Function(
  KidComponent enemy,
  Vector2 aim,
  double charge,
);

enum _AiPhase { wait, sidestep, charge, recover }

/// Charge, jittered aim, and an occasional sidestep. One controller per rival.
class EnemyController extends Component {
  EnemyController({
    required this.host,
    required this.players,
    required this.wave,
    required this.rng,
    required this.laneMin,
    required this.laneMax,
    required this.onFire,
    required this.isFighting,
    required double initialDelay,
  }) : _timer = initialDelay;

  final KidComponent host;
  final List<KidComponent> players;
  final int wave;
  final math.Random rng;
  final double laneMin;
  final double laneMax;
  final EnemyFire onFire;
  final bool Function() isFighting;

  _AiPhase _phase = _AiPhase.wait;
  double _timer;
  double _charge = 0;
  double _stepLeft = 0;
  double _stepSpeed = 0;
  Vector2 _aim = Vector2(-1, -0.5);

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
        final dx = _stepSpeed * dt;
        host.position.x = (host.position.x + dx).clamp(laneMin, laneMax);
        host.setWalking(true);
        _stepLeft -= dx.abs();
        if (_stepLeft <= 0) {
          host.setWalking(false);
          _beginCharge();
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
    final step = EnemyAi.sidestep(rng);
    if (step == 0) {
      _beginCharge();
      return;
    }
    _phase = _AiPhase.sidestep;
    _stepLeft = step.abs();
    _stepSpeed = (step < 0 ? -1 : 1) * 150;
    host.setWalking(true);
  }

  void _beginCharge() {
    final index = EnemyAi.pickLivingIndex(
      [for (final kid in players) !kid.isKo],
      rng,
    );
    if (index == null) {
      _phase = _AiPhase.recover;
      _timer = 0.4;
      host.clearChargePose();
      return;
    }
    final target = players[index];
    final aim = ThrowPhysics.defaultAim(host.throwOrigin, target.hitCenter);
    _aim = EnemyAi.jitterAim(
      aim,
      rng,
      CombatRules.enemyAimJitterRadians(wave),
    );
    _charge = 0;
    _phase = _AiPhase.charge;
    host.showChargePose();
  }
}
