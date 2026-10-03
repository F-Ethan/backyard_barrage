import 'dart:math' as math;

import 'package:flame/extensions.dart';

import '../meta/difficulty.dart';
import 'arena_grid.dart';

/// Target pick, grid step, and aim scatter for the backyard rivals.
class EnemyAi {
  const EnemyAi._();

  static int? pickLivingIndex(List<bool> living, math.Random rng) {
    final options = <int>[];
    for (var i = 0; i < living.length; i++) {
      if (living[i]) options.add(i);
    }
    if (options.isEmpty) return null;
    return options[rng.nextInt(options.length)];
  }

  /// Prefer a living kid inside the thrower's ±1 row lane.
  static int? pickLaneTarget(
    List<bool> living,
    List<int> rows,
    int throwerRow,
    math.Random rng,
  ) {
    final inLane = <int>[];
    for (var i = 0; i < living.length; i++) {
      if (!living[i]) continue;
      final row = i < rows.length ? rows[i] : throwerRow;
      if ((row - throwerRow).abs() <= 1) inLane.add(i);
    }
    if (inLane.isNotEmpty) return inLane[rng.nextInt(inLane.length)];
    return pickLivingIndex(living, rng);
  }

  /// Seconds until the next throw, inside the difficulty's band.
  static double throwGap(math.Random rng, DifficultyTuning tuning) {
    return tuning.throwGap(rng.nextDouble());
  }

  /// Lane check cadence. [every] of 1 runs after each throw. Easy uses 2,
  /// so a rival steps on throws 2, 4, 6… The throw that just happened is
  /// [throwsCompleted].
  static bool shouldAdjustLane(int throwsCompleted, int every) {
    if (throwsCompleted <= 0) return false;
    if (every <= 1) return true;
    return throwsCompleted % every == 0;
  }

  /// One orthogonal step for a rival on the enemy half.
  ///
  /// Column 0 is the column closest to the players. A hit steps away
  /// (column + 1). A lob that falls short steps closer (column − 1).
  /// Otherwise Easy and Normal step one row toward the nearest uncovered
  /// player when nobody is within one row, and only on [laneEvery]. Hard
  /// ([matchPlayerRow]) keeps stepping until it shares that player's row.
  ///
  /// The step is the free neighbor closest to that goal. Rivals will not
  /// stand on a teammate.
  static ({int column, int row})? planBotStep({
    required int column,
    required int row,
    required List<int> playerRows,
    required List<bool> living,
    required int laneEvery,
    required bool matchPlayerRow,
    required int throwsCompleted,
    required bool shotFellShort,
    required bool retreat,
    List<({int column, int row})> occupied = const [],
    int approach = -1,
  }) {
    final closer = approach == 0 ? -1 : approach;
    if (retreat) {
      final away = _closestFreeStep(
        column: column,
        row: row,
        goalColumn: column - closer,
        goalRow: row,
        occupied: occupied,
      );
      if (away != null && away.column == column - closer) return away;
      final threat = _goalRow(
        row: row,
        playerRows: playerRows,
        living: living,
        occupied: const [],
        cover: 0,
      );
      if (threat == null || threat != row) return null;
      final leave = row == 0
          ? 1
          : (row >= ArenaGrid.rows - 1 ? row - 1 : row + 1);
      return _closestFreeStep(
        column: column,
        row: row,
        goalColumn: column,
        goalRow: leave,
        occupied: occupied,
      );
    }

    if (_sharingCell((column: column, row: row), occupied)) {
      final slide = _closestFreeStep(
        column: column,
        row: row,
        goalColumn: column > 0 ? column - 1 : column,
        goalRow: row,
        occupied: occupied,
      );
      if (slide != null) return slide;
      return _anyFreeNeighbor(column, row, occupied);
    }

    final laneTurn = shouldAdjustLane(throwsCompleted, laneEvery);
    final goal = _goalRow(
      row: row,
      playerRows: playerRows,
      living: living,
      occupied: occupied,
      cover: matchPlayerRow ? 0 : 1,
    );
    final aligned = goal == null
        ? true
        : matchPlayerRow
        ? goal == row
        : _anyoneWithin(
            row: row,
            playerRows: playerRows,
            living: living,
            tolerance: 1,
          );

    if (laneTurn && !aligned) {
      final along = _closestFreeStep(
        column: column,
        row: row,
        goalColumn: column,
        goalRow: goal,
        occupied: occupied,
      );
      if (along != null) return along;
      // The row ahead is taken. Slide to a free column and try again next throw.
      final around = _anyFreeNeighbor(column, row, occupied);
      if (around != null) return around;
    }

    final nextColumn = column + closer;
    if (shotFellShort &&
        nextColumn >= 0 &&
        nextColumn < ArenaGrid.columnsPerSide) {
      return _closestFreeStep(
        column: column,
        row: row,
        goalColumn: nextColumn,
        goalRow: row,
        occupied: occupied,
      );
    }

    return null;
  }

  static bool _anyoneWithin({
    required int row,
    required List<int> playerRows,
    required List<bool> living,
    required int tolerance,
  }) {
    for (var i = 0; i < living.length; i++) {
      if (!living[i]) continue;
      final playerRow = i < playerRows.length ? playerRows[i] : row;
      if ((playerRow - row).abs() <= tolerance) return true;
    }
    return false;
  }

  /// Nearest living player row. A player already covered by a teammate
  /// loses to an open one, so the crew spreads instead of stacking.
  static int? _goalRow({
    required int row,
    required List<int> playerRows,
    required List<bool> living,
    required List<({int column, int row})> occupied,
    required int cover,
  }) {
    int? bestRow;
    var bestScore = 1 << 30;
    for (var i = 0; i < living.length; i++) {
      if (!living[i]) continue;
      final playerRow = i < playerRows.length ? playerRows[i] : row;
      var covered = false;
      for (final spot in occupied) {
        if ((spot.row - playerRow).abs() <= cover) {
          covered = true;
          break;
        }
      }
      final score = (playerRow - row).abs() + (covered ? 100 : 0);
      if (score < bestScore) {
        bestScore = score;
        bestRow = playerRow;
      }
    }
    return bestRow;
  }

  static ({int column, int row})? _anyFreeNeighbor(
    int column,
    int row,
    List<({int column, int row})> occupied,
  ) {
    final options = <({int column, int row})>[
      (column: column - 1, row: row),
      (column: column, row: row - 1),
      (column: column, row: row + 1),
      (column: column + 1, row: row),
    ];
    for (final spot in options) {
      if (spot.column < 0 || spot.column >= ArenaGrid.columnsPerSide) continue;
      if (spot.row < 0 || spot.row >= ArenaGrid.rows) continue;
      if (_taken(spot.column, spot.row, occupied)) continue;
      return spot;
    }
    return null;
  }

  static bool _sharingCell(
    ({int column, int row}) here,
    List<({int column, int row})> occupied,
  ) {
    for (final spot in occupied) {
      if (spot.column == here.column && spot.row == here.row) return true;
    }
    return false;
  }

  static bool _taken(
    int column,
    int row,
    List<({int column, int row})> occupied,
  ) {
    return _sharingCell((column: column, row: row), occupied);
  }

  /// Free neighbor that most reduces the distance to the goal cell.
  /// One axis only, and only if it actually gets closer.
  static ({int column, int row})? _closestFreeStep({
    required int column,
    required int row,
    required int goalColumn,
    required int goalRow,
    required List<({int column, int row})> occupied,
  }) {
    final here = (column - goalColumn).abs() + (row - goalRow).abs();
    ({int column, int row})? best;
    var bestDist = here;
    void consider(int dColumn, int dRow) {
      final nextColumn = column + dColumn;
      final nextRow = row + dRow;
      if (nextColumn < 0 || nextColumn >= ArenaGrid.columnsPerSide) return;
      if (nextRow < 0 || nextRow >= ArenaGrid.rows) return;
      if (_taken(nextColumn, nextRow, occupied)) return;
      final dist = (nextColumn - goalColumn).abs() + (nextRow - goalRow).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = (column: nextColumn, row: nextRow);
      }
    }

    consider(0, -1);
    consider(0, 1);
    consider(-1, 0);
    consider(1, 0);
    return best;
  }

  /// A single orthogonal cell: one row or one column, never both, never two.
  static ({int column, int row}) gridStep(math.Random rng) {
    if (rng.nextBool()) {
      return (column: 0, row: rng.nextBool() ? 1 : -1);
    }
    return (column: rng.nextBool() ? 1 : -1, row: 0);
  }

  /// Multiplier on throw distance. Higher [radians] (early waves) miss more.
  static double rangeScatter(math.Random rng, double radians) {
    final span = radians.clamp(0.0, 0.45);
    return 1 + (rng.nextDouble() * 2 - 1) * span;
  }

  /// Unit aim vector rotated by at most [radians] in either direction.
  static Vector2 jitterAim(Vector2 aim, math.Random rng, double radians) {
    final base = aim.length2 < 1e-6 ? Vector2(-1, -0.45) : aim;
    final angle = math.atan2(base.y, base.x);
    final delta = (rng.nextDouble() * 2 - 1) * radians;
    final next = angle + delta;
    return Vector2(math.cos(next), math.sin(next));
  }
}
