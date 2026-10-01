import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Simple centered text banner (KO / Wave clear).
class OverlayBanner extends PositionComponent {
  OverlayBanner({
    required this.label,
    required Vector2 position,
    this.fontSize = 42,
    this.color = const Color(0xFFFFF8F0),
  }) : super(
         position: position,
         size: Vector2(640, 80),
         anchor: Anchor.center,
         priority: 100,
       );

  String label;
  final double fontSize;
  final Color color;

  @override
  void render(Canvas canvas) {
    final bg = Paint()..color = const Color(0xAA2C3E50);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)),
      bg,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.x);
    painter.paint(
      canvas,
      Offset(
        (size.x - painter.width) / 2,
        (size.y - painter.height) / 2,
      ),
    );
  }
}
