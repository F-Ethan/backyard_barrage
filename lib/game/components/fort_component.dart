import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../arena_grid.dart';
import '../combat_rules.dart';
import 'kid_component.dart';

/// Fort on one side of the yard. Intact cover hides one or two kids and
/// absorbs lobs that are not at the top of their arc. Damage swaps in the
/// damaged stage art. At 0 HP the collapsed art stays, the cover is gone,
/// and shots from both sides pass through until the next wave.
class FortComponent extends SpriteComponent {
  FortComponent({
    required this.side,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
         priority: 12,
       );

  final KidSide side;
  int stage = 1;
  int maxHp = 1;
  int hp = 1;

  /// Cover row for this wave. Always inside the mid-depth band.
  int coverRow = ArenaGrid.coverRow;
  Sprite? intact;
  Sprite? damaged;
  Sprite? collapsed;

  bool get standing => hp > 0;

  bool get showingDamage => hp > 0 && hp < maxHp;

  bool get isCollapsed => hp <= 0;

  /// First column of the pair this fort stands on. The main forts use
  /// [ArenaGrid.coverColumnA]; bought extra forts can stand on any pair.
  int coverColumn = ArenaGrid.coverColumnA;

  /// The two cover cells this fort occupies. Shots meet the fort here.
  Rect get footprint => ArenaGrid.fortFootprint(side, coverRow, coverColumn);

  /// Where a rival's snowball meets this fort: taller than [footprint], as
  /// tall as a kid's hit reach, so a lob aimed a little off a kid standing
  /// behind the wall cannot slip past its edge and still hit them.
  Rect get shieldFootprint =>
      ArenaGrid.fortFootprint(side, coverRow, coverColumn, shieldHalfRows);

  /// Half-height of [shieldFootprint], in rows.
  static const double shieldHalfRows = 0.8;

  /// True when [column] on this fort's side is behind it (away from the
  /// river).
  bool isBehind(int column) =>
      side == KidSide.player ? column < coverColumn : column > coverColumn + 1;

  /// Puts the fort on a usable row. Columns stay on the cover pair, off
  /// the back line, so a kid can still shelter and peak a short lob over it.
  void placeOnRow(int row) {
    var next = row;
    if (next < ArenaGrid.fortRowMin) next = ArenaGrid.fortRowMin;
    if (next > ArenaGrid.fortRowMax) next = ArenaGrid.fortRowMax;
    placeAt(row: next, column: ArenaGrid.coverColumnA);
  }

  /// Puts the fort on any [row] and column pair starting at [column].
  void placeAt({required int row, required int column}) {
    coverRow = row.clamp(0, ArenaGrid.rows - 1);
    coverColumn = column.clamp(0, ArenaGrid.columnsPerSide - 2);
    position = ArenaGrid.fortAnchor(side, coverRow, coverColumn);
    _syncDepth();
  }

  Rect get hitRect => CombatRules.fortHitRect(
    stage: stage,
    anchorBottomCenter: position,
    spriteSize: size,
  );

  void applyStage({
    required int nextStage,
    required Sprite intactSprite,
    required Sprite damagedSprite,
    required Sprite collapsedSprite,
  }) {
    stage = nextStage;
    intact = intactSprite;
    damaged = damagedSprite;
    collapsed = collapsedSprite;
    maxHp = CombatRules.fortMaxHp(stage);
    hp = maxHp;
    opacity = 1;
    _syncSprite();
  }

  /// Knocked flat in one go (Fort cracker).
  void collapse() {
    if (hp <= 0) return;
    hp = 0;
    _syncSprite();
  }

  void takeHit() {
    if (hp <= 0) return;
    hp -= 1;
    _syncSprite();
  }

  /// True when [kid] is standing on one of the two cover cells and the fort
  /// is still up.
  bool shelters(KidComponent kid) {
    if (hp <= 0 || kid.isKo || kid.side != side) return false;
    final cell = ArenaGrid.nearestCell(kid.side, kid.position);
    return cell.row == coverRow &&
        (cell.column == coverColumn || cell.column == coverColumn + 1);
  }

  void _syncSprite() {
    if (hp <= 0) {
      sprite = collapsed ?? sprite;
      _syncDepth();
      return;
    }
    _syncDepth();
    if (hp < maxHp) {
      sprite = damaged ?? intact ?? sprite;
      return;
    }
    sprite = intact ?? sprite;
  }

  /// In front of kids on this cover row, behind kids closer to the camera.
  /// A collapsed fort stays behind the kids.
  void _syncDepth() {
    if (hp <= 0) {
      priority = 5;
      return;
    }
    priority = ArenaGrid.depthOrder(ArenaGrid.laneY(coverRow)) + 1;
  }
}
