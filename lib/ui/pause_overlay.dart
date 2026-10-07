import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'draft_button.dart';
import 'motion.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 420;
    return ModalShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SheetSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  const UiGlyph(kind: UiIconKind.pause, size: 48),
                  SizedBox(height: tokens.space.sm),
                ],
                const Text('Paused', style: BarrageType.title),
                SizedBox(height: tokens.space.xs),
                const Text('The yard is frozen.', style: BarrageType.muted),
                SizedBox(height: tokens.space.lg),
                DraftImageButton(
                  key: const Key('resume-button'),
                  label: 'Resume',
                  leadingIcon: Icons.play_arrow_rounded,
                  width: 240,
                  height: compact ? 54 : 60,
                  fontSize: 18,
                  feel: game.feel,
                  onPressed: game.resumeMatch,
                ),
                SizedBox(height: tokens.space.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DraftImageButton(
                      key: const Key('pause-settings'),
                      label: 'Settings',
                      secondary: true,
                      leadingKind: UiIconKind.settings,
                      width: 160,
                      height: 50,
                      fontSize: 15,
                      feel: game.feel,
                      onPressed: game.openSettings,
                    ),
                    SizedBox(width: tokens.space.md),
                    DraftImageButton(
                      key: const Key('pause-menu'),
                      label: 'Menu',
                      secondary: true,
                      leadingIcon: Icons.home_rounded,
                      width: 140,
                      height: 50,
                      fontSize: 15,
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
    );
  }
}
