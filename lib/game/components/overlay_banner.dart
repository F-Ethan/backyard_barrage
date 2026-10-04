import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Cream ink banner for KO, wave clear, and defeat.
class OverlayBanner extends PositionComponent {
  OverlayBanner({
    required this.label,
    required Vector2 position,
    this.subtitle,
    this.fontSize = 42,
    this.color = const Color(0xFF1A2332),
  }) : super(
         position: position,
         size: Vector2(760, subtitle == null ? 108 : 140),
         anchor: Anchor.center,
         priority: 4000,
       );

  String label;
  final String? subtitle;
  final double fontSize;
  final Color color;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 6)),
      Paint()..color = const Color(0x241A2332),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFFF8F0));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x2E1A2332)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final subtitle = this.subtitle;
    final blockHeight = subtitle == null ? fontSize : fontSize + 28;
    var top = (size.y - blockHeight) / 2;
    top = _paintLine(canvas, label, top: top, fontSize: fontSize, color: color);
    if (subtitle != null) {
      _paintLine(
        canvas,
        subtitle,
        top: top + 8,
        fontSize: 22,
        color: const Color(0xFF1A2332),
      );
    }
  }

  double _paintLine(
    Canvas canvas,
    String text, {
    required double top,
    required double fontSize,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.x - 32);
    painter.paint(canvas, Offset((size.x - painter.width) / 2, top));
    return top + painter.height;
  }
}
