import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

/// Minimal Flame placeholder for the Backyard Barrage MVP scaffold.
class BackyardBarrageGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF1B5E20);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;

    world.add(
      TitleBanner(
        position: Vector2.zero(),
      ),
    );

    // Simple circle "kid" placeholder on the left side of the yard.
    world.add(
      CircleComponent(
        radius: 28,
        position: Vector2(-180, 40),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFFFCC80),
      ),
    );
  }
}

class TitleBanner extends PositionComponent {
  TitleBanner({super.position})
      : super(
          size: Vector2(420, 64),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Backyard Barrage',
        style: TextStyle(
          color: Color(0xFFE8F5E9),
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
}
