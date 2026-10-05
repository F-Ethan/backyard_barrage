import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../meta/skill_tree.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'season_chip.dart';

/// Between-wave skill tree. One branch at a time, each a short chain.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  SkillBranch _branch = SkillBranch.throwSpeed;

  Future<void> _buy(String id) async {
    if (!widget.game.meta.buy(id)) return;
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
    final fromDefeat = game.shoppingFromDefeat;
    final chain = SkillTree.chain(_branch);
    return Material(
      color: BarrageColors.scrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: KitPanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fromDefeat ? 'Skills' : 'Wave ${game.wave} clear',
                        style: BarrageType.heading.copyWith(fontSize: 22),
                      ),
                    ),
                    if (!fromDefeat)
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
                const SizedBox(height: 6),
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
                      SizedBox(
                        width: 132,
                        child: ListView(
                          children: [
                            for (final branch in SkillBranch.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _BranchChip(
                                  label: branch.label,
                                  selected: branch == _branch,
                                  onTap: () => setState(() => _branch = branch),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            for (var i = 0; i < chain.length; i++)
                              _NodeRow(
                                node: chain[i],
                                owned: meta.owns(chain[i].id),
                                unlocked:
                                    meta.canBuy(chain[i].id) ||
                                    meta.owns(chain[i].id) ||
                                    (chain[i].parentId != null &&
                                        meta.owns(chain[i].parentId!)) ||
                                    chain[i].parentId == null,
                                affordable: meta.canBuy(chain[i].id),
                                feel: game.feel,
                                onBuy: () => _buy(chain[i].id),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                DraftImageButton(
                  key: const Key('next-wave'),
                  label: fromDefeat ? 'Back' : 'Next wave',
                  onPressed: game.continueFromShop,
                  width: 230,
                  height: 56,
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

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BarrageColors.player : BarrageColors.cream,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BarrageType.body.copyWith(
              fontSize: 14,
              color: selected ? BarrageColors.onPrimary : BarrageColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.owned,
    required this.unlocked,
    required this.affordable,
    required this.onBuy,
    required this.feel,
  });

  final SkillNode node;
  final bool owned;
  final bool unlocked;
  final bool affordable;
  final VoidCallback onBuy;
  final FeelBus feel;

  @override
  Widget build(BuildContext context) {
    final locked = !owned && !unlocked;
    final nextThrow = node.id.startsWith('throw-') && affordable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: owned
              ? const Color(0xFFE7F2FF)
              : locked
              ? const Color(0xFFF3F0EA)
              : BarrageColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: owned ? BarrageColors.player : const Color(0xFFE4D8C8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      style: BarrageType.heading.copyWith(fontSize: 15),
                    ),
                    Text(
                      locked ? 'Unlock the node above first.' : node.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BarrageType.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (owned)
                Text(
                  'Owned',
                  style: BarrageType.body.copyWith(
                    color: BarrageColors.player,
                    fontSize: 13,
                  ),
                )
              else
                DraftImageButton(
                  key: Key(nextThrow ? 'buy-throw' : 'skill-${node.id}'),
                  label: locked ? 'Locked' : 'Buy ${node.cost}',
                  enabled: affordable,
                  onPressed: onBuy,
                  width: 108,
                  height: 40,
                  fontSize: 13,
                  feel: feel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
