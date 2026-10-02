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
      color: BarrageColors.scrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: KitPanel(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Wave ${game.wave} clear',
                        style: BarrageType.heading.copyWith(fontSize: 22),
                      ),
                    ),
                    Text(
                      '+${game.lastReward}',
                      style: BarrageType.body.copyWith(
                        color: BarrageColors.player,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    CoinAmount(amount: meta.coins),
                  ],
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  width: 230,
                  height: 64,
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
      footer: DraftImageButton(
        key: buttonKey,
        label: label,
        enabled: enabled,
        onPressed: onPressed,
        expand: true,
        fontSize: 14,
        feel: feel,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: BarrageType.heading.copyWith(fontSize: 16),
          ),
          Text(rank, textAlign: TextAlign.center, style: BarrageType.muted),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: BarrageType.muted.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
