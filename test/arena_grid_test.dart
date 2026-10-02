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
}
