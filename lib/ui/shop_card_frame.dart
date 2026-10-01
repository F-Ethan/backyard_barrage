import 'package:flutter/material.dart';

import 'barrage_colors.dart';
import 'ui_assets.dart';

/// Wood shop frame. The art well is transparent, so a cream fill sits inside it.
class ShopCardFrame extends StatelessWidget {
  const ShopCardFrame({super.key, required this.child, this.wide = false});

  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(wide ? UiAssets.shopCardWide : UiAssets.shopCard),
          fit: BoxFit.fill,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wide ? 18 : 14,
          wide ? 12 : 18,
          wide ? 18 : 14,
          wide ? 12 : 12,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BarrageColors.cream.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(wide ? 18 : 22),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}
