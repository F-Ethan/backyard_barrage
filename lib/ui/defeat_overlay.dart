import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
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
    return Material(
      color: const Color(0xCC2C3E50),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BarrageColors.cream,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: BarrageColors.ink, width: 4),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Crew down',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Waves cleared $cleared · Coins ${meta.coins} · Best ${meta.bestWave}',
                      style: const TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DraftImageButton(
                          key: const Key('retry'),
                          label: 'Retry',
                          onPressed: game.retryFromDefeat,
                          width: 160,
                          height: 48,
                        ),
                        const SizedBox(width: 12),
                        DraftImageButton(
                          key: const Key('back-to-menu'),
                          label: 'Menu',
                          asset: 'assets/images/ui/btn_secondary_draft.png',
                          onPressed: game.exitToMenu,
                          width: 160,
                          height: 48,
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
