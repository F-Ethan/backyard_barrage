import 'dart:math' as math;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('far rows draw at 75 percent and match a snowball on that row', () {
    expect(
      ArenaGrid.depthScale(ArenaGrid.rowBack, groundTrack: false),
      closeTo(ArenaGrid.depthScaleFar, 0.001),
    );
    expect(
      ArenaGrid.depthScale(ArenaGrid.rowFront, groundTrack: false),
      closeTo(ArenaGrid.depthScaleNear, 0.001),
    );
    expect(ArenaGrid.depthScaleFar, closeTo(0.75, 0.001));
    expect(
      ArenaGrid.depthScale(ArenaGrid.laneY(0), groundTrack: true),
      closeTo(ArenaGrid.depthScaleFar, 0.001),
    );
    expect(
      ArenaGrid.depthScale(
        ArenaGrid.laneY(ArenaGrid.rows - 1),
        groundTrack: true,
      ),
      closeTo(ArenaGrid.depthScaleNear, 0.001),
    );
    for (var row = 0; row < ArenaGrid.rows; row++) {
      expect(
        ArenaGrid.depthScale(ArenaGrid.rowY(row), groundTrack: false),
        closeTo(
          ArenaGrid.depthScale(ArenaGrid.laneY(row), groundTrack: true),
          0.001,
        ),
      );
    }
    expect(
      ArenaGrid.depthScale(ArenaGrid.rowY(0), groundTrack: false),
      lessThan(ArenaGrid.depthScale(ArenaGrid.rowY(4), groundTrack: false)),
    );
  });

  test('each side has more rows than columns and a neutral gap', () {
    expect(ArenaGrid.columnsPerSide, inInclusiveRange(3, 5));
    expect(ArenaGrid.rows, inInclusiveRange(7, 10));
    expect(ArenaGrid.rows, greaterThan(ArenaGrid.columnsPerSide));
    expect(ArenaGrid.verticalSpan, greaterThan(ArenaGrid.horizontalSpan));
    expect(ArenaGrid.playerRight, lessThan(ArenaGrid.enemyLeft));
    expect(
      ArenaGrid.inNeutral((ArenaGrid.playerRight + ArenaGrid.enemyLeft) / 2),
      isTrue,
    );
    expect(ArenaGrid.inNeutral(ArenaGrid.playerLeft), isFalse);
    expect(ArenaGrid.inNeutral(ArenaGrid.enemyRight), isFalse);
  });

  test('player cells stay out of the enemy half', () {
    for (var column = 0; column < ArenaGrid.columnsPerSide; column++) {
      for (var row = 0; row < ArenaGrid.rows; row++) {
        final player = ArenaGrid.cellCenter(KidSide.player, column, row);
        final enemy = ArenaGrid.cellCenter(KidSide.enemy, column, row);
        expect(player.x, lessThanOrEqualTo(ArenaGrid.playerRight));
        expect(enemy.x, greaterThanOrEqualTo(ArenaGrid.enemyLeft));
        expect(ArenaGrid.inNeutral(player.x), isFalse);
        expect(ArenaGrid.inNeutral(enemy.x), isFalse);
      }
    }
  });

  test('fort cover is two player cells', () {
    expect(ArenaGrid.coverCellCount, inInclusiveRange(1, 2));
    expect(
      ArenaGrid.isCoverCell(ArenaGrid.coverColumnA, ArenaGrid.coverRow),
      isTrue,
    );
    expect(
      ArenaGrid.isCoverCell(ArenaGrid.coverColumnB, ArenaGrid.coverRow),
      isTrue,
    );
    expect(ArenaGrid.isCoverCell(0, ArenaGrid.coverRow), isFalse);
  });

  test('fort footprint is the two cover cells on each side', () {
    for (final side in [KidSide.player, KidSide.enemy]) {
      final box = ArenaGrid.fortFootprint(side);
      final lane = ArenaGrid.laneY(ArenaGrid.coverRow);
      final a = ArenaGrid.cellCenter(
        side,
        ArenaGrid.coverColumnA,
        ArenaGrid.coverRow,
      );
      final b = ArenaGrid.cellCenter(
        side,
        ArenaGrid.coverColumnB,
        ArenaGrid.coverRow,
      );
      expect(box.contains(Offset(a.x, lane)), isTrue);
      expect(box.contains(Offset(b.x, lane)), isTrue);
      final behind = ArenaGrid.cellCenter(side, 0, ArenaGrid.coverRow);
      final front = ArenaGrid.cellCenter(side, 3, ArenaGrid.coverRow);
      expect(box.contains(Offset(behind.x, lane)), isFalse);
      expect(box.contains(Offset(front.x, lane)), isFalse);
      final otherRow = ArenaGrid.laneY(ArenaGrid.coverRow + 2);
      expect(box.contains(Offset(a.x, otherRow)), isFalse);
    }
  });

  test('fort rows stay in the mid band and off the back line', () {
    expect(ArenaGrid.fortRowMin, greaterThan(0));
    expect(ArenaGrid.fortRowMax, lessThan(ArenaGrid.rows - 1));
    expect(ArenaGrid.fortRowIsUsable(0), isFalse);
    expect(ArenaGrid.fortRowIsUsable(ArenaGrid.rows - 1), isFalse);
    expect(ArenaGrid.fortRowIsUsable(ArenaGrid.coverRow), isTrue);
    expect(ArenaGrid.coverColumnA, greaterThan(0));
    expect(ArenaGrid.coverColumnB, lessThan(ArenaGrid.columnsPerSide - 1));
    expect(ArenaGrid.columnIsBehindFort(KidSide.player, 0), isTrue);
    expect(ArenaGrid.columnIsBehindFort(KidSide.enemy, 3), isTrue);

    final seen = <int>{};
    final rng = math.Random(1);
    final baseline = ArenaGrid.fortFootprint(KidSide.player);
    for (var i = 0; i < 24; i++) {
      final row = ArenaGrid.rollFortRow(rng);
      seen.add(row);
      expect(ArenaGrid.fortRowIsUsable(row), isTrue);
      final box = ArenaGrid.fortFootprint(KidSide.player, row);
      expect(box.left, closeTo(baseline.left, 0.01));
      expect(box.right, closeTo(baseline.right, 0.01));
    }
    expect(seen.length, greaterThan(1));
  });
}
