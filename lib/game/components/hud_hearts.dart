import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'kid_component.dart';

/// Tiny HP pips for the enemy (top-right).
class HudHearts extends PositionComponent {
  HudHearts({
    required this.target,
    Sprite? heartSprite,
  }) : _heartSprite = heartSprite,
       super(
         position: Vector2(1100, 28),
         size: Vector2(150, 40),
         priority: 90,
       );

  final KidComponent target;
  final Sprite? _heartSprite;

  @override
  void render(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Enemy',
        style: TextStyle(
          color: const Color(0xFFF4F8FC),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Color(0xAA2C3E50), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(0, 0));

    final heart = _heartSprite;
    for (var i = 0; i < target.maxHp; i++) {
      final filled = i < target.hp;
      final x = i * 36.0;
      if (heart != null) {
        final opacity = filled ? 1.0 : 0.25;
        canvas.saveLayer(
          Rect.fromLTWH(x, 16, 28, 28),
          Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
        );
        heart.render(canvas, position: Vector2(x, 16), size: Vector2(28, 28));
        canvas.restore();
      } else {
        final p = Paint()
          ..color = filled ? const Color(0xFFE74C3C) : const Color(0x55333333);
        canvas.drawCircle(Offset(x + 12, 28), 10, p);
      }
    }
  }
}
