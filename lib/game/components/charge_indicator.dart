import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Charge ring + bar near the throwing kid; aim arrow while charging.
class ChargeIndicator extends PositionComponent {
  ChargeIndicator({Sprite? glowSprite})
    : _glowSprite = glowSprite,
      super(priority: 30);

  final Sprite? _glowSprite;
  double charge = 0;
  bool visibleCharge = false;
  Vector2 aimDir = Vector2(1, -0.5);
  Vector2 anchorWorld = Vector2.zero();

  @override
  void render(Canvas canvas) {
    if (!visibleCharge) return;

    final glow = _glowSprite;
    if (glow != null) {
      final scale = 0.55 + charge * 0.55;
      final size = 90.0 * scale;
      glow.render(
        canvas,
        position: Vector2(anchorWorld.x - size / 2, anchorWorld.y - size / 2),
        size: Vector2.all(size),
      );
    }

    const barW = 72.0;
    const barH = 10.0;
    final barLeft = anchorWorld.x - barW / 2;
    final barTop = anchorWorld.y - 70;
    final bg = Paint()..color = const Color(0xCC2C3E50);
    final fill = Paint()..color = const Color(0xFFFFE66D);
    final border = Paint()
      ..color = const Color(0xFFF4F8FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barTop, barW, barH),
        const Radius.circular(4),
      ),
      bg,
    );
    final amount = charge.clamp(0.0, 1.0);
    final full = amount >= 0.995;
    fill.color = full ? const Color(0xFFFFFFFF) : const Color(0xFFFFE66D);
    if (full) border.strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barTop, barW * amount, barH),
        const Radius.circular(4),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barTop, barW, barH),
        const Radius.circular(4),
      ),
      border,
    );
    final label = full ? 'FULL' : '${(amount * 100).round()}%';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: full ? const Color(0xFFFFE66D) : const Color(0xFFFFF8F0),
          fontSize: full ? 14 : 12,
          fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Color(0xCC2C3E50), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(anchorWorld.x - painter.width / 2, barTop - painter.height - 2),
    );
    if (full) {
      canvas.drawCircle(
        Offset(anchorWorld.x, anchorWorld.y),
        46,
        Paint()
          ..color = const Color(0xFFFFE66D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final dir = aimDir.clone();
    if (dir.length2 < 1e-6) {
      dir.setValues(1, -0.5);
    }
    dir.normalize();
    final tip = Offset(
      anchorWorld.x + dir.x * (55 + charge * 40),
      anchorWorld.y + dir.y * (55 + charge * 40),
    );
    final arrow = Paint()
      ..color = const Color(0xEEFFE66D)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(anchorWorld.x, anchorWorld.y), tip, arrow);
  }
}
