import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../meta/skill_tree.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'season_toggle.dart';

/// Between-wave skill tree. Three tabs, then one short chain.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  SkillGroup _group = SkillGroup.fight;
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

  void _selectGroup(SkillGroup group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      if (!group.branches.contains(_branch)) {
        _branch = group.branches.first;
      }
    });
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BarrageType.heading.copyWith(fontSize: 22),
                      ),
                    ),
                    _SeasonPill(season: meta.season, onChanged: _setSeason),
                    if (!fromDefeat) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${game.lastReward}',
                        style: BarrageType.body.copyWith(
                          color: BarrageColors.player,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    CoinAmount(amount: meta.coins),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 148,
                        child: ListView(
                          children: [
                            for (final group in SkillGroup.values) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _BranchChip(
                                  key: Key('skill-group-${group.name}'),
                                  label: group.label,
                                  selected: group == _group,
                                  onTap: () => _selectGroup(group),
                                ),
                              ),
                              if (group == _group)
                                for (final branch in group.branches)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      bottom: 4,
                                    ),
                                    child: _BranchChip(
                                      key: Key('skill-branch-${branch.name}'),
                                      label: branch.label,
                                      selected: branch == _branch,
                                      compact: true,
                                      onTap: () =>
                                          setState(() => _branch = branch),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            Text(
                              _branch.label,
                              style: BarrageType.heading.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            for (var i = 0; i < chain.length; i++)
                              _NodeRow(
                                node: chain[i],
                                owned: meta.owns(chain[i].id),
                                lockReason: meta.lockReason(chain[i].id),
                                affordable: meta.canBuy(chain[i].id),
                                continues: i < chain.length - 1,
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

class _SeasonPill extends StatelessWidget {
  const _SeasonPill({required this.season, required this.onChanged});

  final Season season;
  final ValueChanged<Season> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6FFF8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SeasonToggle(season: season, onChanged: onChanged),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BarrageColors.player : BarrageColors.cream,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 5 : 7,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BarrageType.body.copyWith(
              fontSize: compact ? 13 : 14,
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
    required this.lockReason,
    required this.affordable,
    required this.continues,
    required this.onBuy,
    required this.feel,
  });

  final SkillNode node;
  final bool owned;
  final String? lockReason;
  final bool affordable;
  final bool continues;
  final VoidCallback onBuy;
  final FeelBus feel;

  @override
  Widget build(BuildContext context) {
    final locked = !owned && lockReason != null;
    final nextThrow = node.id.startsWith('throw-') && affordable;
    final rail = locked ? const Color(0xFFD5D0C8) : BarrageColors.player;
    return Padding(
      key: Key(locked ? 'locked-${node.id}' : 'open-${node.id}'),
      padding: const EdgeInsets.only(bottom: 2),
      child: Stack(
        children: [
          if (continues)
            const Positioned(
              left: 7,
              top: 24,
              bottom: 0,
              child: SizedBox(
                width: 2,
                child: ColoredBox(color: Color(0xFFD9E4F5)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: owned
                        ? BarrageColors.player
                        : locked
                        ? const Color(0xFFE4E0D8)
                        : BarrageColors.cream,
                    border: Border.all(color: rail, width: 2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: owned
                          ? const Color(0xFFE7F2FF)
                          : locked
                          ? const Color(0xFFE8E4DC)
                          : BarrageColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: owned
                            ? BarrageColors.player
                            : locked
                            ? const Color(0xFFD5D0C8)
                            : const Color(0xFFE4D8C8),
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
                                  style: BarrageType.heading.copyWith(
                                    fontSize: 15,
                                    color: locked
                                        ? BarrageColors.inkMuted
                                        : BarrageColors.ink,
                                  ),
                                ),
                                Text(
                                  lockReason ?? node.detail,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: BarrageType.muted.copyWith(
                                    fontSize: 12,
                                  ),
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
                              key: Key(
                                nextThrow ? 'buy-throw' : 'skill-${node.id}',
                              ),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
