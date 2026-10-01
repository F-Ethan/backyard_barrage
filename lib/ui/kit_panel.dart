import 'package:flutter/material.dart';

import 'ui_assets.dart';

/// Frosted cream sheet from `panel_modal_v2.png`.
class KitPanel extends StatelessWidget {
  const KitPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(40, 36, 40, 28),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(UiAssets.panel),
            fit: BoxFit.fill,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}