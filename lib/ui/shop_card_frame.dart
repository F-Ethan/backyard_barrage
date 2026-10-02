import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui_assets.dart';

/// Soft v2 shop card. [child] sits in the transparent well; [footer] sits on
/// the price pill at the bottom.
class ShopCardFrame extends StatelessWidget {
  const ShopCardFrame({
    super.key,
    required this.child,
    required this.footer,
  });

  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }
        var width = maxW;
        var height = width * 640 / 512;
        if (height > maxH) {
          height = maxH;
          width = height * 512 / 640;
        }
        final footerH = math.min(50.0, math.max(40.0, height * 0.22));
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(UiAssets.shopCard, fit: BoxFit.fill),
                ),
                Positioned(
                  left: width * 0.12,
                  right: width * 0.12,
                  top: height * 0.09,
                  bottom: height * 0.08 + footerH,
                  child: child,
                ),
                Positioned(
                  left: width * 0.12,
                  right: width * 0.12,
                  bottom: height * 0.07,
                  height: footerH,
                  child: footer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}