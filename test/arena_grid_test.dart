import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
