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

    test('lane checks follow the difficulty, and steps chase or fall back', () {
      expect(EnemyAi.shouldAdjustLane(0, 2), isFalse);
      expect(EnemyAi.shouldAdjustLane(1, 2), isFalse);
      expect(EnemyAi.shouldAdjustLane(2, 2), isTrue);
      expect(EnemyAi.shouldAdjustLane(3, 2), isFalse);
      expect(EnemyAi.shouldAdjustLane(1, 1), isTrue);

      final easy = DifficultyTuning.of(Difficulty.easy);
      final normal = DifficultyTuning.of(Difficulty.normal);
      final hard = DifficultyTuning.of(Difficulty.hard);
      expect(easy.throwsPerStep, greaterThan(normal.throwsPerStep));
      expect(normal.throwsPerStep, 1);
      expect(hard.throwsPerStep, 1);
      expect(easy.matchPlayerRow, isFalse);
      expect(normal.matchPlayerRow, isFalse);
      expect(hard.matchPlayerRow, isTrue);

      ({int column, int row})? step({
        required DifficultyTuning profile,
        required int throwsCompleted,
        int column = 2,
        int row = 4,
        List<int> playerRows = const [1],
        bool shotFellShort = false,
        bool retreat = false,
        List<({int column, int row})> occupied = const [],
      }) {
        return EnemyAi.planBotStep(
          column: column,
          row: row,
          playerRows: playerRows,
          living: [for (var i = 0; i < playerRows.length; i++) true],
          laneEvery: profile.throwsPerStep,
          matchPlayerRow: profile.matchPlayerRow,
          throwsCompleted: throwsCompleted,
          shotFellShort: shotFellShort,
          retreat: retreat,
          occupied: occupied,
        );
      }

      expect(step(profile: easy, throwsCompleted: 1), isNull);
      expect(step(profile: easy, throwsCompleted: 1, shotFellShort: true), (
        column: 1,
        row: 4,
      ));
      expect(step(profile: easy, throwsCompleted: 2), (column: 2, row: 3));
      expect(
        step(profile: normal, throwsCompleted: 1, playerRows: const [4]),
        isNull,
      );
      expect(
        step(profile: normal, throwsCompleted: 1, playerRows: const [5]),
        isNull,
      );
      expect(step(profile: normal, throwsCompleted: 1), (column: 2, row: 3));
      expect(step(profile: hard, throwsCompleted: 1, playerRows: const [5]), (
        column: 2,
        row: 5,
      ));
      expect(
        step(profile: hard, throwsCompleted: 1, playerRows: const [4]),
        isNull,
      );
      expect(
        step(
          profile: normal,
          throwsCompleted: 1,
          playerRows: const [4],
          shotFellShort: true,
        ),
        (column: 1, row: 4),
      );
      expect(
        step(
          profile: normal,
          throwsCompleted: 1,
          column: 0,
          playerRows: const [4],
          shotFellShort: true,
        ),
        isNull,
      );
      expect(step(profile: normal, throwsCompleted: 1, retreat: true), (
        column: 3,
        row: 4,
      ));
      expect(
        step(
          profile: normal,
          throwsCompleted: 1,
          column: 3,
          retreat: true,
          playerRows: const [4],
        ),
        (column: 3, row: 5),
      );
      final blocked = step(
        profile: normal,
        throwsCompleted: 1,
        occupied: const [(column: 2, row: 3)],
      );
      expect(blocked, isNotNull);
      expect(blocked, isNot(equals((column: 2, row: 3))));
      expect(
        step(
          profile: normal,
          throwsCompleted: 1,
          playerRows: const [1, 6],
          occupied: const [(column: 1, row: 1)],
        ),
        (column: 2, row: 5),
      );

      ({int column, int row})? ally({
        required bool shotFellShort,
        required bool retreat,
        int column = 1,
        int row = 4,
      }) {
        return EnemyAi.planBotStep(
          column: column,
          row: row,
          playerRows: const [4],
          living: const [true],
          laneEvery: 2,
          matchPlayerRow: false,
          throwsCompleted: 2,
          shotFellShort: shotFellShort,
          retreat: retreat,
          approach: 1,
        );
      }

      expect(ally(shotFellShort: true, retreat: false), (column: 2, row: 4));
      expect(
        ally(shotFellShort: false, retreat: true, column: 2),
        (column: 1, row: 4),
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
