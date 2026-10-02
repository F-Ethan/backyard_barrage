import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'ui_assets.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width.clamp(0.0, 520.0).toDouble();
    final height = (size.height - 24).clamp(0.0, 340.0).toDouble();
    return Material(
      color: BarrageColors.scrim,
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: width > 48 ? width - 24 : width,
            height: height > 48 ? height : 280,
            child: KitPanel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(UiAssets.iconPause, width: 48, height: 48),
                  const SizedBox(height: 8),
                  const Text('Paused', style: BarrageType.title),
                  const SizedBox(height: 4),
                  const Text(
                    'The yard is frozen.',
                    style: BarrageType.muted,
                  ),
                  const SizedBox(height: 14),
                  DraftImageButton(
                    key: const Key('resume-button'),
                    label: 'Resume',
                    width: 210,
                    height: 64,
                    feel: game.feel,
                    onPressed: game.resumeMatch,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DraftImageButton(
                        key: const Key('pause-settings'),
                        label: 'Settings',
                        asset: UiAssets.secondary,
                        leading: UiAssets.iconSettings,
                        width: 168,
                        height: 52,
                        fontSize: 15,
                        feel: game.feel,
                        onPressed: game.openSettings,
                      ),
                      const SizedBox(width: 10),
                      DraftImageButton(
                        key: const Key('pause-menu'),
                        label: 'Menu',
                        asset: UiAssets.secondary,
                        width: 140,
                        height: 52,
                        feel: game.feel,
                        onPressed: game.exitToMenu,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
