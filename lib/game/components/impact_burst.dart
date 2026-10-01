import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

/// Brief impact VFX that auto-removes.
class ImpactBurst extends SpriteComponent {
  ImpactBurst({
    required Sprite sprite,
    required Vector2 position,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2.all(96),
         anchor: Anchor.center,
         priority: 25,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.35),
          EffectController(duration: 0.12, curve: Curves.easeOut),
        ),
        OpacityEffect.to(
          0,
          EffectController(duration: 0.18, curve: Curves.easeIn),
        ),
        RemoveEffect(),
      ]),
    );
  }
}
