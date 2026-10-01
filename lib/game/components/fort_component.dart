import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../combat_rules.dart';

/// Player-side fort. Blocks enemy lobs until its HP is gone for the wave.
class FortComponent extends SpriteComponent {
  FortComponent({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
         priority: 6,
       );

  int stage = 1;
  int maxHp = 1;
  int hp = 1;

  Rect get hitRect => CombatRules.fortHitRect(
        stage: stage,
        anchorBottomCenter: position,
        spriteSize: size,
      );

  void applyStage(int nextStage, Sprite nextSprite) {
    stage = nextStage;
    sprite = nextSprite;
    maxHp = CombatRules.fortMaxHp(stage);
    hp = maxHp;
    opacity = 1;
  }

  void takeHit() {
    if (hp <= 0) return;
    hp -= 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = hp > 0 ? 1.0 : 0.45;
    if (opacity != target) opacity = target;
  }
}
