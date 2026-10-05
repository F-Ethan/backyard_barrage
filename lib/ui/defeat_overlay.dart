import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'season_chip.dart';

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
    final cleared = game.wave - 1;
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 32).clamp(320.0, 680.0).toDouble();
    final height = (size.height - 24).clamp(240.0, 440.0).toDouble();
    return Material(
      color: BarrageColors.scrim,
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: KitPanel(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Crew down', style: BarrageType.title),
                    const SizedBox(height: 4),
                    const Text(
                      'The run resets. Unspent coins carry over.',
                      style: BarrageType.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Waves cleared $cleared · Best ${meta.bestWave}',
                      style: BarrageType.body,
                    ),
                    const SizedBox(height: 4),
                    CoinAmount(amount: meta.coins),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SeasonChip(
                          season: Season.winter,
                          selected: meta.season == Season.winter,
                          onTap: () => _setSeason(Season.winter),
                        ),
                        const SizedBox(width: 8),
                        SeasonChip(
                          season: Season.summer,
                          selected: meta.season == Season.summer,
                          onTap: () => _setSeason(Season.summer),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DraftImageButton(
                      key: const Key('open-skills'),
                      label: 'Skills',
                      secondary: true,
                      onPressed: game.openSkillTree,
                      width: 180,
                      height: 48,
                      feel: game.feel,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DraftImageButton(
                          key: const Key('retry'),
                          label: 'Retry',
                          onPressed: game.retryFromDefeat,
                          width: 180,
                          height: 58,
                          feel: game.feel,
                        ),
                        const SizedBox(width: 12),
                        DraftImageButton(
                          key: const Key('back-to-menu'),
                          label: 'Menu',
                          secondary: true,
                          onPressed: game.exitToMenu,
                          width: 160,
                          height: 52,
                          feel: game.feel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
