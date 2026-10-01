import 'package:flutter/material.dart';

import 'barrage_colors.dart';
import 'ui_assets.dart';

class CoinAmount extends StatelessWidget {
  const CoinAmount({
    super.key,
    required this.amount,
    this.prefix = '',
    this.fontSize = 16,
  });

  final int amount;
  final String prefix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(UiAssets.coin, width: fontSize + 8, height: fontSize + 8),
        const SizedBox(width: 4),
        Text(
          '$prefix$amount',
          style: TextStyle(
            color: BarrageColors.ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
