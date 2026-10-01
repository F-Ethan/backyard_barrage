import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../meta/meta_state.dart';

/// Coin icon plus the banked soft-currency total.
class CoinReadout extends PositionComponent {
  CoinReadout({
    required this.meta,
    required Sprite coin,
  }) : _coin = coin,
       super(
         position: Vector2(16, 128),
         size: Vector2(160, 32),
         priority: 90,
       );

  final MetaState meta;
  final Sprite _coin;

  @override
  void render(Canvas canvas) {
    _coin.render(canvas, position: Vector2.zero(), size: Vector2.all(26));
    final painter = TextPainter(
      text: TextSpan(
        text: '${meta.coins}',
        style: const TextStyle(
          color: Color(0xFFF1C40F),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Color(0xAA2C3E50), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(32, 2));
  }
}
