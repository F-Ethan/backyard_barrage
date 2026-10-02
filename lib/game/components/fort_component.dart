import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../arena_grid.dart';
import '../combat_rules.dart';
import 'kid_component.dart';

/// Player-side fort. Intact cover hides one or two kids and absorbs enemy
/// lobs. Damage swaps in the damaged stage art; at 0 HP the collapsed art
/// stays and the cover is gone until the next wave.
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
  Sprite? intact;
  Sprite? damaged;
  Sprite? collapsed;

  bool get standing => hp > 0;

  bool get showingDamage => hp > 0 && hp < maxHp;

  bool get isCollapsed => hp <= 0;

  /// The two cover cells this fort occupies. Shots meet the fort here.
  Rect get footprint => ArenaGrid.fortFootprint(side);

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
    return ArenaGrid.isCoverCell(cell.column, cell.row);
  }

  void _syncSprite() {
    if (hp <= 0) {
      sprite = collapsed ?? sprite;
      priority = 5;
      return;
    }
    priority = 12;
    if (hp < maxHp) {
      sprite = damaged ?? intact ?? sprite;
      return;
    }
    sprite = intact ?? sprite;
  }
}
