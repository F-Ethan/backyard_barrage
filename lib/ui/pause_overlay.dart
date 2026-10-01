import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'ui_assets.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MatchPhase>(
      valueListenable: game.phaseListenable,
      builder: (context, phase, _) {
        final show = phase == MatchPhase.fight || phase == MatchPhase.clearing;
        if (!show) return const SizedBox.shrink();
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DraftImageButton(
                key: const Key('pause-button'),
                label: 'Pause',
                asset: UiAssets.secondary,
                width: 148,
                height: 46,
                feel: game.feel,
                onPressed: game.pauseMatch,
              ),
            ),
          ),
        );
      },
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC2C3E50),
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: 520,
            height: 280,
            child: KitPanel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Paused',
                    style: TextStyle(
                      color: BarrageColors.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The yard is frozen.',
                    style: TextStyle(
                      color: BarrageColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DraftImageButton(
                    key: const Key('resume-button'),
                    label: 'Resume',
                    width: 200,
                    height: 48,
                    feel: game.feel,
                    onPressed: game.resumeMatch,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DraftImageButton(
                        key: const Key('pause-settings'),
                        label: 'Settings',
                        asset: UiAssets.secondary,
                        width: 150,
                        height: 44,
                        feel: game.feel,
                        onPressed: game.openSettings,
                      ),
                      const SizedBox(width: 10),
                      DraftImageButton(
                        key: const Key('pause-menu'),
                        label: 'Menu',
                        asset: UiAssets.secondary,
                        width: 150,
                        height: 44,
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
