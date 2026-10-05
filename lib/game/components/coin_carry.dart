import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Short defeat beat. The existing coin sprite rises, and the label is the
/// unspent wallet from the moment the crew went down.
class CoinCarry extends PositionComponent {
  CoinCarry({
    required this.sprite,
    required this.amount,
    required Vector2 position,
  }) : super(
         position: position,
         size: Vector2(460, 170),
         anchor: Anchor.center,
         priority: 4200,
       );

  final Sprite sprite;
  final int amount;
  double _age = 0;

  String get label => 'Carried over $amount';

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / 1.2).clamp(0.0, 1.0);
    final bob = math.sin(t * math.pi) * 26;
    sprite.render(
      canvas,
      position: Vector2(size.x / 2, 4 - bob),
      size: Vector2.all(64),
      anchor: Anchor.topCenter,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1A2332),
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - 16);
    painter.paint(canvas, Offset((size.x - painter.width) / 2, 92));
  }
}
