import 'dart:math' as math;

import 'package:backyard_barrage/game/enemy_ai.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnemyAi', () {
    test('picks only a living kid', () {
      final rng = math.Random(3);
      expect(EnemyAi.pickLivingIndex([false, false, false], rng), isNull);
      expect(EnemyAi.pickLivingIndex([false, true, false], rng), 1);
      final pick = EnemyAi.pickLivingIndex([true, false, true], math.Random(1));
      expect(pick == 0 || pick == 2, isTrue);
    });

    test('sidestep stays inside its distance and can hold still', () {
      final held = EnemyAi.sidestep(math.Random(1), chance: 0);
      expect(held, 0);
      final rng = math.Random(4);
      for (var i = 0; i < 12; i++) {
        final step = EnemyAi.sidestep(
          rng,
          chance: 1,
          minDistance: 36,
          maxDistance: 90,
        );
        expect(step.abs(), inInclusiveRange(36, 90));
      }
    });

    test('grid steps prefer rows over columns', () {
      final rng = math.Random(4);
      var rowSteps = 0;
      var columnSteps = 0;
      for (var i = 0; i < 400; i++) {
        final nudge = EnemyAi.gridNudge(rng);
        if (nudge.column == 0 && nudge.row != 0) rowSteps++;
        if (nudge.column != 0) columnSteps++;
        expect(nudge.column.abs(), lessThanOrEqualTo(1));
        expect(nudge.row.abs(), lessThanOrEqualTo(2));
      }
      expect(rowSteps, greaterThan(columnSteps));
    });

    test('aim jitter stays inside the requested angle', () {
      final base = Vector2(-1, -0.4);
      final baseAngle = math.atan2(base.y, base.x);
      final straight = EnemyAi.jitterAim(base, math.Random(1), 0);
      expect(math.atan2(straight.y, straight.x), closeTo(baseAngle, 1e-6));

      final rng = math.Random(9);
      const jitter = 0.2;
      for (var i = 0; i < 24; i++) {
        final aim = EnemyAi.jitterAim(base, rng, jitter);
        var delta = math.atan2(aim.y, aim.x) - baseAngle;
        while (delta > math.pi) {
          delta -= math.pi * 2;
        }
        while (delta < -math.pi) {
          delta += math.pi * 2;
        }
        expect(delta.abs(), lessThanOrEqualTo(jitter + 1e-9));
        expect(aim.length, closeTo(1, 1e-6));
      }
    });
  });
}
