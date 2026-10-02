import 'dart:math' as math;

import 'package:backyard_barrage/game/enemy_ai.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
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

    test('a grid step is one orthogonal cell', () {
      final rng = math.Random(4);
      var rowSteps = 0;
      var columnSteps = 0;
      for (var i = 0; i < 40; i++) {
        final step = EnemyAi.gridStep(rng);
        final axes = (step.column == 0 ? 0 : 1) + (step.row == 0 ? 0 : 1);
        expect(axes, 1);
        expect(step.column.abs(), lessThanOrEqualTo(1));
        expect(step.row.abs(), lessThanOrEqualTo(1));
        if (step.row != 0) rowSteps++;
        if (step.column != 0) columnSteps++;
      }
      expect(rowSteps, greaterThan(0));
      expect(columnSteps, greaterThan(0));
    });

    test('rivals step once every few throws, more often on hard', () {
      expect(EnemyAi.shouldGridStep(0, 3), isFalse);
      expect(EnemyAi.shouldGridStep(1, 3), isFalse);
      expect(EnemyAi.shouldGridStep(2, 3), isFalse);
      expect(EnemyAi.shouldGridStep(3, 3), isTrue);
      expect(EnemyAi.shouldGridStep(4, 3), isFalse);
      expect(EnemyAi.shouldGridStep(6, 3), isTrue);

      final easy = DifficultyTuning.of(Difficulty.easy);
      final normal = DifficultyTuning.of(Difficulty.normal);
      final hard = DifficultyTuning.of(Difficulty.hard);
      expect(easy.throwsPerStep, greaterThan(normal.throwsPerStep));
      expect(hard.throwsPerStep, lessThan(normal.throwsPerStep));
      expect(
        EnemyAi.shouldGridStep(hard.throwsPerStep, hard.throwsPerStep),
        isTrue,
      );
      expect(
        EnemyAi.shouldGridStep(hard.throwsPerStep - 1, hard.throwsPerStep),
        isFalse,
      );
    });

    test('throw gaps stay inside each difficulty band', () {
      final normal = DifficultyTuning.of(Difficulty.normal);
      final easy = DifficultyTuning.of(Difficulty.easy);
      final hard = DifficultyTuning.of(Difficulty.hard);
      expect(normal.throwGapMin, 1.5);
      expect(normal.throwGapMax, 3);
      expect(easy.throwGapMin, greaterThanOrEqualTo(normal.throwGapMax));
      expect(hard.throwGapMax, lessThanOrEqualTo(1.5));
      expect(hard.throwGapMin, greaterThanOrEqualTo(1));
      expect(normal.friendlyFortDamage, isFalse);
      expect(easy.friendlyFortDamage, isFalse);
      expect(hard.friendlyFortDamage, isTrue);
      expect(easy.playerMoveScale, greaterThan(normal.playerMoveScale));
      expect(hard.playerMoveScale, lessThan(normal.playerMoveScale));
      final playerPace = ThrowPhysics.kidMoveSpeed();
      expect(hard.enemyStepSpeed, greaterThan(playerPace));
      expect(hard.enemyStepSpeed, lessThan(playerPace * 4));

      final rng = math.Random(2);
      for (var i = 0; i < 12; i++) {
        final gap = EnemyAi.throwGap(rng, normal);
        expect(gap, inInclusiveRange(normal.throwGapMin, normal.throwGapMax));
      }
      final later = DifficultyTuning.of(Difficulty.normal, wave: 8);
      expect(later.throwGapMin, greaterThanOrEqualTo(1.5));
      expect(later.throwGapMax, lessThanOrEqualTo(3));
      expect(later.throwGapMax, lessThan(normal.throwGapMax));
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
