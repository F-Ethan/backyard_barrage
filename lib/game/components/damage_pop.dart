import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// "-1" (or "Blocked") that pops over a kid when a hit lands, rises a
/// little, and fades.
class DamagePop extends PositionComponent {
  DamagePop({
    required this.text,
    required Vector2 position,
    this.color = const Color(0xFFFF4D4D),
  }) : super(position: position, anchor: Anchor.center, priority: 3600);

  final String text;
  final Color color;

  static const double lifetime = 0.75;
  static const double rise = 46;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0.0, 1.0);
    final alpha = t < 0.55 ? 1.0 : 1 - (t - 0.55) / 0.45;
    final pop = t < 0.12 ? 0.8 + 3 * t : 1.0;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 26 * pop,
          fontWeight: FontWeight.w900,
          color: color.withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: const Color(0xFF1A2332).withValues(alpha: alpha * 0.85),
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2 - rise * t),
    );
  }
}
