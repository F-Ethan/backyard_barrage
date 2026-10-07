import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../arena_grid.dart';

/// Brief impact VFX that auto-removes.
class ImpactBurst extends SpriteComponent {
  /// [depthY] sorts the burst against kids. It defaults to [position], but
  /// a splash drawn above a kid's body should paint in front of that kid.
  ImpactBurst({
    required Sprite sprite,
    required Vector2 position,
    double? depthY,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2.all(96),
         anchor: Anchor.center,
         priority: ArenaGrid.depthOrder(depthY ?? position.y) + 1,
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
