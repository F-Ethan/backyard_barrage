import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../arena_grid.dart';
import 'kid_component.dart';

/// A broken iron shield that drops into the snow where a kid's shield
/// took its last hit. It stays put if the kid walks off, sits just behind
/// them, and fades away after a few seconds.
class ShieldPile extends SpriteComponent {
  ShieldPile._({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required int priority,
    required bool mirror,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.bottomCenter,
         priority: priority,
       ) {
    if (mirror) flipHorizontallyAroundCenter();
  }

  /// Where the pile goes on [kid]'s art (fractions of the 512² render,
  /// from the artist's `shield_offsets.json`): the crew's at x 0.6, the
  /// rivals' flipped at x 0.4.
  factory ShieldPile.under(KidComponent kid, Sprite sprite) {
    final rival = kid.side == KidSide.enemy;
    final centerX = rival ? 0.40 : 0.60;
    final bottomY = rival ? 0.9547 : 0.9568;
    final width = rival ? 0.65 : 0.636;
    // The render is a 471px square starting 20.5px into the 512 art,
    // scaled about the feet by the kid's draw and depth scale.
    const crop = 471.0;
    const left = 20.5;
    final box = kid.size;
    final grow = kid.drawScale * kid.scale.x;
    final local = Vector2(
      (centerX * 512 - left) / crop * box.x,
      bottomY * 512 / crop * box.y,
    );
    final fromFeet = (local - Vector2(box.x / 2, box.y))..scale(grow);
    final w = width * 512 / crop * box.x * grow;
    return ShieldPile._(
      sprite: sprite,
      position: kid.position + fromFeet,
      size: Vector2(w, w / 2),
      // Behind the kid, so it does not cover the front boot.
      priority: ArenaGrid.depthOrder(kid.hitCenter.y) - 1,
      mirror: rival,
    );
  }

  /// Seconds it lies there before fading, and the fade.
  static const double holdSeconds = 2.5;
  static const double fadeSeconds = 0.6;

  /// It drops this far onto the snow before it settles.
  static const double fallPixels = 18;
  static const double fallSeconds = 0.18;

  @override
  void onLoad() {
    position.y -= fallPixels;
    add(
      MoveByEffect(
        Vector2(0, fallPixels),
        EffectController(duration: fallSeconds, curve: Curves.easeIn),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: fadeSeconds, startDelay: holdSeconds),
        onComplete: removeFromParent,
      ),
    );
  }
}
