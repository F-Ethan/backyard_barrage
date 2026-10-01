import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../meta/meta_state.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'season_chip.dart';
import 'shop_card_frame.dart';

class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  Future<void> _buy(bool Function() action) async {
    if (!action()) return;
    widget.game.feel.purchased();
    setState(() {});
    await widget.game.persist();
  }

  Future<void> _setSeason(Season season) async {
    await widget.game.setSeason(season);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final meta = game.meta;
    return Material(
      color: const Color(0xCC2C3E50),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: KitPanel(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 76,
                  child: ShopCardFrame(
                    wide: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wave ${game.wave} clear',
                            style: const TextStyle(
                              color: BarrageColors.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '+${game.lastReward}',
                          style: const TextStyle(
                            color: BarrageColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        CoinAmount(amount: meta.coins),
                      ],
                    ),
                  ),
                ),
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
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _UpgradeCard(
                          title: 'Extra kid',
                          rank: 'Crew ${meta.crewSize}/${MetaState.maxCrew}',
                          detail: 'Another kid joins next wave.',
                          buttonKey: const Key('buy-kid'),
                          label: meta.nextKidCost == null
                              ? 'Max'
                              : 'Buy ${meta.nextKidCost}',
                          enabled: meta.canBuyKid,
                          feel: game.feel,
                          onPressed: () => _buy(meta.buyExtraKid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _UpgradeCard(
                          title: 'Fort',
                          rank:
                              'Stage ${meta.fortStage}/${MetaState.maxFortStage}',
                          detail:
                              'Blocks shots until its HP is gone. Refills each wave.',
                          buttonKey: const Key('buy-fort'),
                          label: meta.nextFortCost == null
                              ? 'Max'
                              : 'Buy ${meta.nextFortCost}',
                          enabled: meta.canBuyFort,
                          feel: game.feel,
                          onPressed: () => _buy(meta.buyFort),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _UpgradeCard(
                          title: 'Throw speed',
                          rank:
                              'Rank ${meta.throwRank}/${MetaState.maxThrowRank}',
                          detail: 'Faster charge and a harder lob.',
                          buttonKey: const Key('buy-throw'),
                          label: meta.nextThrowCost == null
                              ? 'Max'
                              : 'Buy ${meta.nextThrowCost}',
                          enabled: meta.canBuyThrow,
                          feel: game.feel,
                          onPressed: () => _buy(meta.buyThrowSpeed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DraftImageButton(
                  key: const Key('next-wave'),
                  label: 'Next wave',
                  onPressed: game.continueFromShop,
                  width: 240,
                  height: 48,
                  feel: game.feel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.title,
    required this.rank,
    required this.detail,
    required this.buttonKey,
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.feel,
  });

  final String title;
  final String rank;
  final String detail;
  final Key buttonKey;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final FeelBus feel;

  @override
  Widget build(BuildContext context) {
    return ShopCardFrame(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BarrageColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            rank,
            style: const TextStyle(
              color: BarrageColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BarrageColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DraftImageButton(
            key: buttonKey,
            label: label,
            enabled: enabled,
            onPressed: onPressed,
            width: 130,
            height: 40,
            feel: feel,
          ),
        ],
      ),
    );
  }
}
