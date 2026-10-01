import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'fort_component.dart';

/// Wood trough + grass fill scaled to remaining fort HP.
class FortBar extends PositionComponent {
  FortBar({
    required this.fort,
    required Sprite empty,
    required Sprite fill,
  }) : _empty = empty,
       _fill = fill,
       super(
         position: Vector2(490, 8),
         size: Vector2(300, 54),
         priority: 90,
       );

  final FortComponent fort;
  final Sprite _empty;
  final Sprite _fill;

  @override
  void render(Canvas canvas) {
    final label = TextPainter(
      text: const TextSpan(
        text: 'Fort',
        style: TextStyle(
          color: Color(0xFFFFF8F0),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset((size.x - label.width) / 2, 0));

    const barTop = 18.0;
    final barSize = Vector2(size.x, 32);
    _empty.render(canvas, position: Vector2(0, barTop), size: barSize);

    final fraction = fort.maxHp <= 0 ? 0.0 : fort.hp / fort.maxHp;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, barTop, size.x * fraction, 32));
    _fill.render(canvas, position: Vector2(0, barTop), size: barSize);
    canvas.restore();
  }
}
