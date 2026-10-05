import 'dart:math' as math;

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
  /// Column 0 stays behind the fort (the back line). Column 3 stays in front.
  static const int coverColumnA = 1;
  static const int coverColumnB = 2;

  /// Default cover row, inside [fortRowMin]..[fortRowMax]. Matches the
  /// geometry tests. A live match rolls a row in that band instead.
  static const int coverRow = 4;

  /// Mid-depth band. Not row 0 or the last row, and not the rows flush
  /// against those edges, so there is always room to walk past the fort.
  static const int fortRowMin = 2;
  static const int fortRowMax = 5;

  /// A throw touch has to start this close to the selected kid's body.
  /// Distant taps must not start a charge.
  static const double moveTouchRadius = 104;

  /// Matches [KidComponent] sprite size so lane Y lines up with hit centers.
  static const double kidSize = 152;

  /// Feet-to-hit-center lift (`size.y * 0.45`).
  static const double bodyLift = kidSize * 0.45;

  /// Paint order for a yard height. Smaller [y] is higher on the screen, so
  /// it paints first and reads as farther away. A snowball whose ground
  /// track is over a hit box therefore draws behind that kid, and one under
  /// the box draws in front. The band stays above the background.
  static int depthOrder(double y) => 200 + y.round();

  /// Far-row size as a fraction of the near-row size. 75% is obvious from
  /// the back line to the camera and still readable on the far row.
  static const double depthScaleFar = 0.75;

  /// Full size at the near edge of the yard (toward the camera).
  static const double depthScaleNear = 1;

  /// Drawn size for a yard height. Same factor on X and Y.
  ///
  /// Kids pass feet Y (`groundTrack: false`), which runs from [rowBack] to
  /// [rowFront]. Snowballs pass ground-track Y (`groundTrack: true`), which
  /// is the lane band one body-lift higher. Both spans are [verticalSpan],
  /// so a ball on a row matches the kid standing on that row. Values outside
  /// the band clamp. This does not change hit sizes.
  static double depthScale(double y, {required bool groundTrack}) {
    final origin = groundTrack ? laneY(0) : rowBack;
    final t = ((y - origin) / verticalSpan).clamp(0.0, 1.0);
    return depthScaleFar + (depthScaleNear - depthScaleFar) * t;
  }

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

  /// Body-height Y for [row]. Projectiles and aim use this, not the feet line.
  static double laneY(int row) => rowY(row) - bodyLift;

  static int rowForLaneY(double y) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var row = 0; row < rows; row++) {
      final distance = (laneY(row) - y).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = row;
      }
    }
    return best;
  }

  /// True when [column] is on the far side of that side's fort (away from
  /// the neutral band). Shots from there have to clear the fort.
  static bool columnIsBehindFort(KidSide side, int column) {
    if (side == KidSide.player) return column < coverColumnA;
    return column > coverColumnB;
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

  static bool fortRowIsUsable(int row) {
    return row >= fortRowMin && row <= fortRowMax;
  }

  /// A cover row that is never the top edge, the bottom edge, or the back line.
  /// Columns stay on [coverColumnA] and [coverColumnB].
  static int rollFortRow(math.Random rng) {
    final span = fortRowMax - fortRowMin + 1;
    return fortRowMin + rng.nextInt(span);
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
  static Vector2 fortAnchor([KidSide side = KidSide.player, int? row]) {
    final coverRow = row ?? ArenaGrid.coverRow;
    final left = cellCenter(side, coverColumnA, coverRow);
    final right = cellCenter(side, coverColumnB, coverRow);
    return Vector2((left.x + right.x) / 2, left.y);
  }

  /// Lane box for the fort: the middle of the two cover cells on [row].
  ///
  /// Wider than the gap between those cells, narrower than half the side,
  /// and only about one row tall. The back column and the front column stay
  /// open, and the rows above and below the fort stay open, so a lob can
  /// pass. Horizontal edges do not move when the row changes.
  static Rect fortFootprint(KidSide side, [int? row]) {
    final coverRow = row ?? ArenaGrid.coverRow;
    final a = cellCenter(side, coverColumnA, coverRow);
    final b = cellCenter(side, coverColumnB, coverRow);
    final centerX = (a.x + b.x) / 2;
    final halfWidth = columnStep * 0.55;
    final mid = laneY(coverRow);
    final halfHeight = rowStep * 0.46;
    return Rect.fromLTRB(
      centerX - halfWidth,
      mid - halfHeight,
      centerX + halfWidth,
      mid + halfHeight,
    );
  }

  /// Drawn fort. Sits on the cover columns instead of covering the half.
  static Vector2 get fortDrawSize {
    final width = columnStep * 1.45;
    final height = rowStep * 3.6;
    return Vector2(width, height);
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
