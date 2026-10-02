import 'package:flame/extensions.dart';

import 'components/kid_component.dart';

/// One cell on a side's movement grid.
class ArenaCell {
  const ArenaCell(this.column, this.row);

  final int column;
  final int row;
}

/// Player and enemy halves of the yard.
///
/// Each side is a short row of columns (forward / back) and a taller stack of
/// rows (up / down). The band between the halves is neutral: nobody crosses.
class ArenaGrid {
  const ArenaGrid._();

  static const int columnsPerSide = 4;
  static const int rows = 8;

  static const double playerLeft = 150;
  static const double playerRight = 360;
  static const double enemyLeft = 900;
  static const double enemyRight = 1110;
  static const double rowBack = 430;
  static const double rowFront = 690;

  /// Two neighboring player cells. One or two kids can stand here in cover.
  static const int coverColumnA = 1;
  static const int coverColumnB = 2;
  static const int coverRow = 4;

  /// Vertical drags change rows sooner than the same drag changes columns.
  static const double rowDrag = 34;
  static const double columnDrag = 76;

  static const List<(int, int)> playerSlots = [(1, 4), (0, 2), (3, 6)];
  static const List<(int, int)> enemySlots = [(2, 3), (3, 1), (1, 6)];

  static double get columnStep =>
      (playerRight - playerLeft) / (columnsPerSide - 1);

  static double get rowStep => (rowFront - rowBack) / (rows - 1);

  static double get verticalSpan => rowFront - rowBack;

  static double get horizontalSpan => playerRight - playerLeft;

  static double columnX(KidSide side, int column) {
    final clamped = column.clamp(0, columnsPerSide - 1);
    final t = clamped / (columnsPerSide - 1);
    if (side == KidSide.player) {
      return playerLeft + (playerRight - playerLeft) * t;
    }
    return enemyLeft + (enemyRight - enemyLeft) * t;
  }

  static double rowY(int row) {
    final clamped = row.clamp(0, rows - 1);
    final t = clamped / (rows - 1);
    return rowBack + (rowFront - rowBack) * t;
  }

  static Vector2 cellCenter(KidSide side, int column, int row) {
    return Vector2(columnX(side, column), rowY(row));
  }

  static Vector2 slot(KidSide side, int index) {
    final slots = side == KidSide.player ? playerSlots : enemySlots;
    final slot = slots[index.clamp(0, slots.length - 1)];
    return cellCenter(side, slot.$1, slot.$2);
  }

  static ArenaCell clampCell(int column, int row) {
    return ArenaCell(
      column.clamp(0, columnsPerSide - 1),
      row.clamp(0, rows - 1),
    );
  }

  static ArenaCell nearestCell(KidSide side, Vector2 feet) {
    var bestColumn = 0;
    var bestRow = 0;
    var best = double.infinity;
    for (var column = 0; column < columnsPerSide; column++) {
      for (var row = 0; row < rows; row++) {
        final distance = cellCenter(side, column, row).distanceToSquared(feet);
        if (distance < best) {
          best = distance;
          bestColumn = column;
          bestRow = row;
        }
      }
    }
    return ArenaCell(bestColumn, bestRow);
  }

  static bool isCoverCell(int column, int row) {
    return row == coverRow &&
        (column == coverColumnA || column == coverColumnB);
  }

  static int get coverCellCount {
    var count = 0;
    for (var column = 0; column < columnsPerSide; column++) {
      for (var row = 0; row < rows; row++) {
        if (isCoverCell(column, row)) count++;
      }
    }
    return count;
  }

  static bool inNeutral(double x) => x > playerRight && x < enemyLeft;

  static Rect field(KidSide side) {
    if (side == KidSide.player) {
      return const Rect.fromLTRB(playerLeft, rowBack, playerRight, rowFront);
    }
    return const Rect.fromLTRB(enemyLeft, rowBack, enemyRight, rowFront);
  }

  /// Body-height band used when the left thumb aims at the enemy half.
  static Rect aimField(KidSide side) {
    final feet = field(side);
    return Rect.fromLTRB(
      feet.left,
      feet.top - 96,
      feet.right,
      feet.bottom - 36,
    );
  }

  static Vector2 clampToRect(Rect rect, Vector2 point) {
    return Vector2(
      point.x.clamp(rect.left, rect.right).toDouble(),
      point.y.clamp(rect.top, rect.bottom).toDouble(),
    );
  }

  /// Bottom-center of the fort art, sitting on the two cover cells.
  static Vector2 fortAnchor() {
    final left = cellCenter(KidSide.player, coverColumnA, coverRow);
    final right = cellCenter(KidSide.player, coverColumnB, coverRow);
    return Vector2((left.x + right.x) / 2, left.y);
  }

  static Vector2 throwOrigin(KidSide side, Vector2 feet, Vector2 size) {
    final facingRight = side == KidSide.player;
    return feet +
        Vector2(facingRight ? size.x * 0.22 : -size.x * 0.22, -size.y * 0.55);
  }

  static Vector2 hitCenter(Vector2 feet, Vector2 size) {
    return feet + Vector2(0, -size.y * 0.45);
  }
}
