import 'package:flutter/material.dart';

import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'ui_assets.dart';

/// Coin sprite + amount. Changes tick toward the new value and the coin
/// gives a small pop; the first build shows the amount as-is.
class CoinAmount extends StatefulWidget {
  const CoinAmount({
    super.key,
    required this.amount,
    this.prefix = '',
    this.fontSize = 16,
    this.color = BarrageColors.ink,
  });

  final int amount;
  final String prefix;
  final double fontSize;
  final Color color;

  @override
  State<CoinAmount> createState() => _CoinAmountState();
}

class _CoinAmountState extends State<CoinAmount> {
  int _pops = 0;

  @override
  void didUpdateWidget(CoinAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) _pops++;
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final coinSize = widget.fontSize + 10;
    final style = BarrageType.heading.copyWith(
      color: widget.color,
      fontSize: widget.fontSize,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(_pops),
          tween: Tween(begin: _pops == 0 ? 1 : 1.3, end: 1),
          duration: motion.slow,
          curve: motion.spring,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Image.asset(UiAssets.coin, width: coinSize, height: coinSize),
        ),
        const SizedBox(width: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(end: widget.amount.toDouble()),
          duration: motion.slow * 1.5,
          curve: motion.enter,
          builder: (context, value, _) =>
              Text('${widget.prefix}${value.round()}', style: style),
        ),
      ],
    );
  }
}
