import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'kid_component.dart';

/// One heart row per kid. Filled pips are remaining HP (2 hits to KO).
class CrewHearts extends PositionComponent {
  CrewHearts({
    required this.kids,
    required this.label,
    required Vector2 position,
    Sprite? heartSprite,
    Sprite? emptyHeartSprite,
  }) : _heart = heartSprite,
       _empty = emptyHeartSprite,
       super(
         position: position,
         size: Vector2(120, 120),
         priority: 90,
       );

  final List<KidComponent> kids;
  final String label;
  final Sprite? _heart;
  final Sprite? _empty;

  @override
  void render(Canvas canvas) {
    final title = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFFFF8F0),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Color(0xAA2C3E50), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    title.paint(canvas, Offset.zero);

    const heartSize = 24.0;
    const gap = 4.0;
    const rowHeight = 28.0;
    for (var row = 0; row < kids.length; row++) {
      final kid = kids[row];
      for (var i = 0; i < kid.maxHp; i++) {
        final filled = i < kid.hp;
        final x = i * (heartSize + gap);
        final y = 18.0 + row * rowHeight;
        final heart = _heart;
        if (heart == null) {
          final paint = Paint()
            ..color = filled ? const Color(0xFFE74C3C) : const Color(0x55333333);
          canvas.drawCircle(Offset(x + 10, y + 10), 8, paint);
          continue;
        }
        final sprite = filled ? heart : (_empty ?? heart);
        sprite.render(
          canvas,
          position: Vector2(x, y),
          size: Vector2.all(heartSize),
        );
      }
    }
  }
}
