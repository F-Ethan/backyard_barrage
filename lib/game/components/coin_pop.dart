import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// "+8" that floats up from a knocked-out rival and fades.
class CoinPop extends PositionComponent {
  CoinPop({required this.amount, required Vector2 position, this.label})
    : super(position: position, anchor: Anchor.center, priority: 3500);

  final int amount;

  /// Text shown instead of "+[amount]" (a power-up reward).
  final String? label;
  static const double lifetime = 0.9;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= 70 * dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0.0, 1.0);
    final alpha = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final pop = t < 0.15 ? 0.7 + 2 * t : 1.0;
    final text = TextPainter(
      text: TextSpan(
        text: label ?? '+$amount',
        style: TextStyle(
          fontSize: 30 * pop,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFF1C40F).withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: const Color(0xFF1A2332).withValues(alpha: alpha * 0.8),
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
  }
}
