import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// A power-up the crew just earned: its icon pops out of whoever paid it
/// (a beaten boss, a scared hound, a rival's dropped potion) with "+1
/// Revive" under it, floats up, and fades.
class RewardFloat extends PositionComponent {
  RewardFloat({
    required this.icon,
    required this.text,
    required Vector2 position,
    this.delay = 0,
  }) : super(position: position, anchor: Anchor.center, priority: 3500);

  final Sprite icon;
  final String text;

  /// Seconds before it appears, so several rewards come out one by one.
  final double delay;

  /// Drawn icon size at full pop.
  static const double iconSize = 64;

  /// Seconds on screen after [delay]. Short enough to finish before the
  /// wave report covers the yard.
  static const double lifetime = 1.15;

  /// How far it rises over its life, in pixels.
  static const double rise = 110;

  double _age = 0;

  double get _t => ((_age - delay) / lifetime).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= delay + lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_age < delay) return;
    final t = _t;
    // Pop in past full size, settle, then rise and fade out at the end.
    final pop = t < 0.18
        ? 0.4 + 0.75 * (t / 0.18)
        : (t < 0.3 ? 1.15 - 0.15 * ((t - 0.18) / 0.12) : 1.0);
    final alpha = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    final lift = -rise * (1 - math.pow(1 - t, 2).toDouble());
    canvas.save();
    canvas.translate(0, lift);
    final side = iconSize * pop;
    // A soft glow behind the icon so it reads on snow.
    canvas.drawCircle(
      Offset.zero,
      side * 0.62,
      Paint()
        ..color = const Color(0xFFFFE66D).withValues(alpha: 0.45 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    icon.render(
      canvas,
      position: Vector2(-side / 2, -side / 2),
      size: Vector2.all(side),
      overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFF1C40F).withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: const Color(0xFF1A2332).withValues(alpha: alpha * 0.8),
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, side / 2 + 2));
    canvas.restore();
  }
}
