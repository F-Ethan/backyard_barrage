import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Aim arrow and charge glow near the throwing kid. The power bar itself
/// lives in the screen-space HUD.
class ChargeIndicator extends PositionComponent {
  ChargeIndicator({Sprite? glowSprite})
    : _glowSprite = glowSprite,
      super(priority: 2000);

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
