import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../meta/skill_tree.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'season_toggle.dart';

/// Between-wave skill tree.
///
/// Crew, Fight, and Defense sit across the top as tabs. The branches for that
/// tab are a side list, and the open branch shows its chain beside it so each
/// rank sits under the one that unlocks it.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

/// Last purchase, so the node and the wallet can celebrate it once.
class _Purchase {
  _Purchase(this.id, this.cost, this.serial);

  final String id;
  final int cost;
  final int serial;
}

class _ShopOverlayState extends State<ShopOverlay> {
  SkillGroup _group = SkillGroup.fight;
  SkillBranch _branch = SkillBranch.throwSpeed;
  _Purchase? _lastPurchase;
  int _purchaseSerial = 0;

  Future<void> _buy(SkillNode node) async {
    if (!widget.game.meta.buy(node.id)) return;
    widget.game.feel.purchased();
    setState(() {
      _lastPurchase = _Purchase(node.id, node.cost, ++_purchaseSerial);
    });
    await widget.game.persist();
  }

  Future<void> _setSeason(Season season) async {
    await widget.game.setSeason(season);
    if (!mounted) return;
    setState(() {});
  }

  void _selectGroup(SkillGroup group) {
    if (group == _group) return;
    widget.game.feel.uiTap();
    setState(() {
      _group = group;
      if (!group.branches.contains(_branch)) {
        _branch = group.branches.first;
      }
    });
  }

  void _selectBranch(SkillBranch branch) {
    if (branch == _branch) return;
    widget.game.feel.uiTap();
    setState(() => _branch = branch);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final meta = game.meta;
    final fromDefeat = game.shoppingFromDefeat;
    final tokens = context.tokens;
    final chain = SkillTree.chain(_branch);
    return ModalShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final insetX = (width * 0.05).clamp(24.0, 64.0);
              final insetY = (height * 0.05).clamp(12.0, 24.0);
              final compact = height < 380;
              return RepaintBoundary(
                key: const Key('shop-sheet'),
                child: SheetSurface(
                  padding: EdgeInsets.fromLTRB(insetX, insetY, insetX, insetY),
                  child: Column(
                    children: [
                      _Header(
                        title: fromDefeat
                            ? 'Skills'
                            : 'Wave ${game.wave} clear',
                        reward: fromDefeat ? null : game.lastReward,
                        coins: meta.coins,
                        purchase: _lastPurchase,
                        season: meta.season,
                        onSeason: _setSeason,
                        compact: compact,
                      ),
                      SizedBox(height: tokens.space.sm),
                      _GroupTabs(selected: _group, onSelect: _selectGroup),
                      SizedBox(height: tokens.space.sm),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, body) {
                            final side = (body.maxWidth * 0.30).clamp(
                              128.0,
                              210.0,
                            );
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: side,
                                  child: MotionSwitcher(
                                    child: _BranchList(
                                      key: ValueKey(_group),
                                      group: _group,
                                      selected: _branch,
                                      onSelect: _selectBranch,
                                    ),
                                  ),
                                ),
                                SizedBox(width: tokens.space.md),
                                Expanded(
                                  child: MotionSwitcher(
                                    slide: const Offset(0.04, 0),
                                    child: ListView(
                                      key: ValueKey(_branch),
                                      padding: EdgeInsets.zero,
                                      children: [
                                        Text(
                                          _branch.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BarrageType.heading,
                                        ),
                                        Text(
                                          'Each rank unlocks the next.',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BarrageType.muted,
                                        ),
                                        SizedBox(height: tokens.space.sm),
                                        for (var i = 0; i < chain.length; i++)
                                          _NodeRow(
                                            node: chain[i],
                                            owned: meta.owns(chain[i].id),
                                            lockReason: meta.lockReason(
                                              chain[i].id,
                                            ),
                                            affordable: meta.canBuy(
                                              chain[i].id,
                                            ),
                                            continues: i < chain.length - 1,
                                            feel: game.feel,
                                            celebrate:
                                                _lastPurchase?.id == chain[i].id
                                                ? _lastPurchase!.serial
                                                : null,
                                            onBuy: () => _buy(chain[i]),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: tokens.space.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DraftImageButton(
                          key: const Key('next-wave'),
                          label: fromDefeat ? 'Back' : 'Next wave',
                          trailingIcon: fromDefeat
                              ? null
                              : Icons.arrow_forward_rounded,
                          leadingIcon: fromDefeat
                              ? Icons.arrow_back_rounded
                              : null,
                          onPressed: game.continueFromShop,
                          width: 220,
                          height: compact ? 48 : 54,
                          fontSize: 17,
                          feel: game.feel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.reward,
    required this.coins,
    required this.purchase,
    required this.season,
    required this.onSeason,
    required this.compact,
  });

  final String title;
  final int? reward;
  final int coins;
  final _Purchase? purchase;
  final Season season;
  final ValueChanged<Season> onSeason;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final purchase = this.purchase;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BarrageType.title.copyWith(fontSize: compact ? 22 : 26),
          ),
        ),
        if (Season.choosable) ...[
          SeasonToggle(season: season, onChanged: onSeason, compact: true),
          SizedBox(width: tokens.space.sm),
        ],
        if (reward != null) ...[
          TagPill(
            color: tokens.ownedTint,
            borderColor: tokens.primary.withValues(alpha: 0.3),
            child: Text(
              '+$reward',
              style: BarrageType.heading.copyWith(
                fontSize: 15,
                color: tokens.primaryDeep,
              ),
            ),
          ),
          SizedBox(width: tokens.space.sm),
        ],
        Stack(
          clipBehavior: Clip.none,
          children: [
            TagPill(child: CoinAmount(amount: coins)),
            if (purchase != null && !motion.reduced)
              Positioned(
                right: tokens.space.sm,
                top: -6,
                child: IgnorePointer(
                  child:
                      Text(
                            '-${purchase.cost}',
                            key: const Key('shop-coin-delta'),
                            style: BarrageType.heading.copyWith(
                              fontSize: 15,
                              color: tokens.accent,
                            ),
                          )
                          .animate(key: ValueKey(purchase.serial))
                          .fadeIn(duration: motion.fast)
                          .moveY(
                            begin: 0,
                            end: -22,
                            duration: motion.slow * 2,
                            curve: motion.enter,
                          )
                          .fadeOut(delay: motion.slow, duration: motion.slow),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Crew / Fight / Defense tabs with a sliding selected pill.
class _GroupTabs extends StatelessWidget {
  const _GroupTabs({required this.selected, required this.onSelect});

  final SkillGroup selected;
  final ValueChanged<SkillGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    const groups = SkillGroup.values;
    final index = groups.indexOf(selected);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.lockedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final tabWidth = box.maxWidth / groups.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: motion.medium,
                curve: motion.spring,
                left: tabWidth * index,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: tokens.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: tokens.shadowPrimary,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final group in groups)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: group == selected,
                        child: GestureDetector(
                          key: Key('skill-group-${group.name}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(group),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: motion.fast,
                              style: BarrageType.button.copyWith(
                                fontSize: 15,
                                color: group == selected
                                    ? tokens.onPrimary
                                    : tokens.inkMuted,
                              ),
                              child: Text(
                                group.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BranchList extends StatelessWidget {
  const _BranchList({
    super.key,
    required this.group,
    required this.selected,
    required this.onSelect,
  });

  final SkillGroup group;
  final SkillBranch selected;
  final ValueChanged<SkillBranch> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final branch in group.branches) ...[
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space.xs),
            child: _BranchTile(
              key: Key('skill-branch-${branch.name}'),
              label: branch.label,
              selected: branch == selected,
              onTap: () => onSelect(branch),
            ),
          ),
        ],
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final onColor = selected ? tokens.primaryDeep : tokens.ink;
    return PressScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: AnimatedContainer(
        duration: motion.medium,
        curve: motion.enter,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space.sm,
          vertical: tokens.space.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.ownedTint : tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? tokens.primary.withValues(alpha: 0.55)
                : tokens.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: BarrageType.body.copyWith(
                  fontSize: 14,
                  color: onColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NodeState { owned, affordable, short, locked }

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.owned,
    required this.lockReason,
    required this.affordable,
    required this.continues,
    required this.onBuy,
    required this.feel,
    this.celebrate,
  });

  final SkillNode node;
  final bool owned;
  final String? lockReason;
  final bool affordable;
  final bool continues;
  final VoidCallback onBuy;
  final FeelBus feel;

  /// Purchase serial when this node was just bought.
  final int? celebrate;

  _NodeState get _state {
    if (owned) return _NodeState.owned;
    if (lockReason != null) return _NodeState.locked;
    return affordable ? _NodeState.affordable : _NodeState.short;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final state = _state;
    final locked = state == _NodeState.locked;
    final nextThrow = node.id.startsWith('throw-') && affordable;
    final rail = switch (state) {
      _NodeState.owned => tokens.primary,
      _NodeState.affordable => tokens.primary,
      _NodeState.short => tokens.primary.withValues(alpha: 0.4),
      _NodeState.locked => tokens.lockedRail,
    };
    final fill = switch (state) {
      _NodeState.owned => tokens.ownedTint,
      _NodeState.affordable => tokens.surface,
      _NodeState.short => tokens.surface,
      _NodeState.locked => tokens.lockedFill,
    };
    final border = switch (state) {
      _NodeState.owned => tokens.primary.withValues(alpha: 0.6),
      _NodeState.affordable => tokens.primary,
      _NodeState.short => tokens.hairline,
      _NodeState.locked => tokens.lockedRail,
    };
    final dotIcon = switch (state) {
      _NodeState.owned => Icons.check_rounded,
      _NodeState.locked => Icons.lock_rounded,
      _ => null,
    };
    Widget card = AnimatedContainer(
      duration: motion.medium,
      curve: motion.enter,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
          width: state == _NodeState.affordable ? 1.5 : 1,
        ),
        boxShadow: state == _NodeState.affordable ? tokens.shadowSoft : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.space.md,
          tokens.space.sm,
          tokens.space.sm,
          tokens.space.sm,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: BarrageType.heading.copyWith(
                    fontSize: 15,
                    color: locked ? tokens.inkMuted : tokens.ink,
                  ),
                ),
                Text(
                  lockReason ?? node.detail,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: BarrageType.muted.copyWith(fontSize: 12),
                ),
              ],
            );
            final action = owned
                ? TagPill(
                    color: tokens.primary,
                    borderColor: tokens.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space.md,
                      vertical: tokens.space.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: tokens.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Owned',
                          maxLines: 1,
                          style: BarrageType.button.copyWith(
                            color: tokens.onPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : DraftImageButton(
                    key: Key(nextThrow ? 'buy-throw' : 'skill-${node.id}'),
                    label: locked ? 'Locked' : 'Buy ${node.cost}',
                    leadingIcon: locked ? Icons.lock_rounded : null,
                    secondary: state == _NodeState.short,
                    enabled: affordable,
                    onPressed: onBuy,
                    width: math.min(116, box.maxWidth),
                    height: 40,
                    fontSize: 14,
                    feel: feel,
                  );
            if (box.maxWidth < 250) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  SizedBox(height: tokens.space.sm),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                SizedBox(width: tokens.space.sm),
                action,
              ],
            );
          },
        ),
      ),
    );
    final serial = celebrate;
    if (serial != null && !motion.reduced) {
      card = card
          .animate(key: ValueKey('bought-$serial'))
          .scale(
            begin: const Offset(1.06, 1.06),
            end: const Offset(1, 1),
            duration: motion.slow,
            curve: motion.spring,
          )
          .shimmer(
            duration: motion.slow * 2,
            color: BarrageColors.coin.withValues(alpha: 0.55),
          );
    }
    return Padding(
      key: Key(locked ? 'locked-${node.id}' : 'open-${node.id}'),
      padding: const EdgeInsets.only(bottom: 2),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (continues)
            Positioned(
              left: 9,
              top: 26,
              bottom: 0,
              child: SizedBox(
                width: 2,
                child: ColoredBox(color: rail.withValues(alpha: 0.35)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedContainer(
                  duration: motion.medium,
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: owned
                        ? tokens.primary
                        : locked
                        ? tokens.lockedFill
                        : tokens.surface,
                    border: Border.all(color: rail, width: 2),
                  ),
                  child: dotIcon == null
                      ? null
                      : Icon(
                          dotIcon,
                          size: 12,
                          color: owned ? tokens.onPrimary : tokens.inkMuted,
                        ),
                ),
              ),
              SizedBox(width: tokens.space.sm),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: tokens.space.xs + 2),
                  child: card,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
