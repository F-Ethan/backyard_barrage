import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../meta/play_mode.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'season_toggle.dart';

class DefeatOverlay extends StatefulWidget {
  const DefeatOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<DefeatOverlay> createState() => _DefeatOverlayState();
}

class _DefeatOverlayState extends State<DefeatOverlay> {
  Future<void> _setSeason(Season season) async {
    await widget.game.setSeason(season);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final meta = game.meta;
    final difficulty = game.feel.settings.difficulty;
    final cleared = game.wave - 1;
    final tokens = context.tokens;
    return ModalShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SheetSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TagPill(
                  child: Text(
                    meta.mode.label.toUpperCase(),
                    style: BarrageType.overline.copyWith(
                      color: tokens.primaryDeep,
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.sm),
                const Text('Crew down', style: BarrageType.title),
                SizedBox(height: tokens.space.xs),
                Text(
                  meta.mode == PlayMode.arcade
                      ? 'Skills reset. Unspent coins carry over.'
                      : 'Skills stay. You restart at wave 1.',
                  style: BarrageType.body,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.space.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: tokens.space.sm,
                  runSpacing: tokens.space.sm,
                  children: [
                    _Stat(label: 'CLEARED', value: '$cleared'),
                    if (meta.mode.showsScore)
                      _Stat(
                        key: const Key('defeat-score'),
                        label: '${difficulty.label.toUpperCase()} SCORE',
                        value: '${meta.score}',
                      )
                    else
                      _Stat(
                        label: '${difficulty.label.toUpperCase()} BEST',
                        value: '${meta.bestWave}',
                      ),
                    TagPill(child: CoinAmount(amount: meta.coins)),
                  ],
                ),
                if (Season.choosable) ...[
                  SizedBox(height: tokens.space.md),
                  SeasonToggle(season: meta.season, onChanged: _setSeason),
                ],
                SizedBox(height: tokens.space.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: tokens.space.md,
                  runSpacing: tokens.space.sm,
                  children: [
                    DraftImageButton(
                      key: const Key('retry'),
                      label: 'Retry',
                      leadingIcon: Icons.replay_rounded,
                      onPressed: game.retryFromDefeat,
                      width: 180,
                      height: 56,
                      fontSize: 18,
                      feel: game.feel,
                    ),
                    DraftImageButton(
                      key: const Key('open-skills'),
                      label: 'Skills',
                      secondary: true,
                      leadingIcon: Icons.auto_awesome_rounded,
                      onPressed: game.openSkillTree,
                      width: 150,
                      height: 56,
                      feel: game.feel,
                    ),
                    DraftImageButton(
                      key: const Key('back-to-menu'),
                      label: 'Menu',
                      back: true,
                      secondary: true,
                      leadingIcon: Icons.home_rounded,
                      onPressed: game.exitToMenu,
                      width: 140,
                      height: 56,
                      feel: game.feel,
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

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return TagPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: BarrageType.overline),
          SizedBox(width: tokens.space.sm),
          Text(
            value,
            style: BarrageType.heading.copyWith(color: tokens.primaryDeep),
          ),
        ],
      ),
    );
  }
}
