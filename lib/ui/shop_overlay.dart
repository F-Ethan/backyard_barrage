import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../game/kid_colors.dart';
import '../meta/power_up.dart';
import '../meta/skill_tree.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'power_up_ui.dart';
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

  /// The Items tab (one-use power-ups) is showing instead of a skill group.
  bool _items = false;
  SkillBranch _branch = SkillBranch.throwSpeed;

  /// Which skills show: a kid's own (Health, Shield, …) by index, or the
  /// team's shared ones when null. Picked with the buttons by Next wave.
  int? _filter = 0;
  _Purchase? _lastPurchase;
  int _purchaseSerial = 0;

  /// The kid a purchase in the open branch goes to: the picked kid for a
  /// personal branch, 0 (unused) for a team one.
  int get _owner => SkillTree.isPersonal(_branch)
      ? (_filter ?? 0).clamp(0, widget.game.meta.crewSize - 1)
      : 0;

  Future<void> _buy(SkillNode node) async {
    final kid = _owner;
    final cost = widget.game.meta.costOf(node.id, kid: kid);
    if (!widget.game.meta.buy(node.id, kid: kid)) return;
    widget.game.feel.purchased();
    setState(() {
      _lastPurchase = _Purchase(node.id, cost, ++_purchaseSerial);
    });
    await widget.game.persist();
  }

  Future<void> _setSeason(Season season) async {
    await widget.game.setSeason(season);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _buyItem(PowerUp item) async {
    final cost = widget.game.meta.itemCost(item);
    if (!widget.game.meta.buyItem(item)) return;
    widget.game.feel.purchased();
    setState(() {
      _lastPurchase = _Purchase(item.name, cost, ++_purchaseSerial);
    });
    await widget.game.persist();
  }

  void _selectItems() {
    if (_items) return;
    widget.game.feel.uiTap();
    setState(() => _items = true);
  }

  void _selectGroup(SkillGroup group) {
    if (group == _group && !_items) return;
    widget.game.feel.uiTap();
    setState(() {
      _items = false;
      _group = group;
      final shown = _shownBranches(group);
      if (!shown.contains(_branch)) {
        _branch = shown.first;
      }
    });
  }

  void _selectBranch(SkillBranch branch) {
    if (branch == _branch) return;
    widget.game.feel.uiTap();
    setState(() => _branch = branch);
  }

  /// Team (null) or Kid 1–3: shows only those skills.
  void _selectFilter(int? filter) {
    if (filter == _filter && !_items) return;
    widget.game.feel.uiTap();
    setState(() {
      _filter = filter;
      _items = false;
      final shown = _shownBranches(_group);
      if (!shown.contains(_branch)) _branch = shown.first;
    });
  }

  /// Branches in [group] for the picked filter (a kid's own, or the
  /// team's) with something this difficulty can buy. Easy hides Recovery:
  /// it already heals everyone between waves.
  List<SkillBranch> _shownBranches(SkillGroup group) => [
    for (final branch in group.branches)
      if (SkillTree.isPersonal(branch) == (_filter != null) &&
          !SkillTree.chain(
            branch,
          ).every((node) => widget.game.meta.hidesNode(node.id)))
        branch,
  ];

  /// Ranks [kid] (or the team) owns in [branch].
  int _ranksOwned(SkillBranch branch, int kid) => SkillTree.chain(
    branch,
  ).where((node) => widget.game.meta.ownsFor(kid, node.id)).length;

  /// The ranks worth showing: the last one owned, then the next few.
  /// A long chain does not list every rank.
  static const int _ranksAhead = 3;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final meta = game.meta;
    final fromDefeat = game.shoppingFromDefeat;
    final tokens = context.tokens;
    final full = [
      for (final node in SkillTree.chain(_branch))
        if (!meta.hidesNode(node.id)) node,
    ];
    final owner = _owner;
    final personal = SkillTree.isPersonal(_branch);
    final next = full.indexWhere((node) => !meta.ownsFor(owner, node.id));
    final from = next < 0
        ? math.max(0, full.length - 1)
        : math.max(0, next - 1);
    final to = next < 0
        ? full.length
        : math.min(full.length, next + _ranksAhead);
    final chain = full.sublist(from, to);
    final hiddenOwned = from;
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
                      _GroupTabs(
                        selected: _items ? null : _group,
                        onSelect: _selectGroup,
                        onItems: _selectItems,
                      ),
                      SizedBox(height: tokens.space.sm),
                      Expanded(
                        child: _items
                            ? _ItemsPanel(
                                game: game,
                                celebrate: _lastPurchase,
                                onBuy: _buyItem,
                              )
                            : LayoutBuilder(
                                builder: (context, body) {
                                  final side = (body.maxWidth * 0.30).clamp(
                                    128.0,
                                    210.0,
                                  );
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: side,
                                        child: MotionSwitcher(
                                          child: _BranchList(
                                            key: ValueKey(_group),
                                            branches: _shownBranches(_group),
                                            ranks: {
                                              for (final branch
                                                  in _shownBranches(_group))
                                                branch: _ranksOwned(
                                                  branch,
                                                  _filter ?? 0,
                                                ),
                                            },
                                            tint: _filter == null
                                                ? null
                                                : KidColors.of(_filter!),
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
                                                hiddenOwned > 0
                                                    ? 'Ranks 1–$hiddenOwned owned. Each rank unlocks the next.'
                                                    : personal
                                                    ? 'Kid ${owner + 1}'
                                                          "'s own skill."
                                                    : 'Shared by the whole crew.',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: BarrageType.muted,
                                              ),
                                              SizedBox(height: tokens.space.sm),
                                              for (
                                                var i = 0;
                                                i < chain.length;
                                                i++
                                              )
                                                _NodeRow(
                                                  node: chain[i],
                                                  cost: meta.costOf(
                                                    chain[i].id,
                                                    kid: owner,
                                                  ),
                                                  owned: meta.ownsFor(
                                                    owner,
                                                    chain[i].id,
                                                  ),
                                                  lockReason: meta.lockReason(
                                                    chain[i].id,
                                                    kid: owner,
                                                  ),
                                                  affordable: meta.canBuy(
                                                    chain[i].id,
                                                    kid: owner,
                                                  ),
                                                  continues:
                                                      from + i <
                                                      full.length - 1,
                                                  feel: game.feel,
                                                  celebrate:
                                                      _lastPurchase?.id ==
                                                          chain[i].id
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
                      Row(
                        children: [
                          const Spacer(),
                          _FilterButton(
                            key: const Key('shop-filter-team'),
                            label: 'Team',
                            color: tokens.primary,
                            selected: !_items && _filter == null,
                            compact: compact,
                            onTap: () => _selectFilter(null),
                          ),
                          for (var i = 0; i < meta.crewSize; i++) ...[
                            SizedBox(width: tokens.space.xs),
                            _FilterButton(
                              key: Key('shop-filter-kid-$i'),
                              label: 'Kid ${i + 1}',
                              color: KidColors.of(i),
                              selected: !_items && _filter == i,
                              compact: compact,
                              onTap: () => _selectFilter(i),
                            ),
                          ],
                          SizedBox(width: tokens.space.md),
                          DraftImageButton(
                            key: const Key('next-wave'),
                            label: fromDefeat ? 'Back' : 'Next wave',
                            back: fromDefeat,
                            trailingIcon: fromDefeat
                                ? null
                                : Icons.arrow_forward_rounded,
                            leadingIcon: fromDefeat
                                ? Icons.arrow_back_rounded
                                : null,
                            onPressed: game.continueFromShop,
                            width: 200,
                            height: compact ? 48 : 54,
                            fontSize: 17,
                            feel: game.feel,
                          ),
                        ],
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
  const _GroupTabs({
    required this.selected,
    required this.onSelect,
    required this.onItems,
  });

  /// Null while the Items tab is showing.
  final SkillGroup? selected;
  final ValueChanged<SkillGroup> onSelect;
  final VoidCallback onItems;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    const groups = SkillGroup.values;
    final tabCount = groups.length + 1;
    final current = selected;
    final index = current == null ? groups.length : groups.indexOf(current);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.lockedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final tabWidth = box.maxWidth / tabCount;
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
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: current == null,
                      child: GestureDetector(
                        key: const Key('shop-tab-items'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onItems,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: motion.fast,
                            style: BarrageType.button.copyWith(
                              fontSize: 15,
                              color: current == null
                                  ? tokens.onPrimary
                                  : tokens.inkMuted,
                            ),
                            child: const Text('Items', maxLines: 1),
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
    required this.branches,
    required this.ranks,
    required this.tint,
    required this.selected,
    required this.onSelect,
  });

  final List<SkillBranch> branches;

  /// Ranks owned in each branch, for the picked kid or the team.
  final Map<SkillBranch, int> ranks;

  /// The picked kid's color, or null for the team.
  final Color? tint;
  final SkillBranch selected;
  final ValueChanged<SkillBranch> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final branch in branches) ...[
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space.xs),
            child: _BranchTile(
              key: Key('skill-branch-${branch.name}'),
              label: branch.label,
              rank: ranks[branch] ?? 0,
              tint: tint,
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
    required this.rank,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int rank;
  final Color? tint;
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
            if (rank > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: (tint ?? tokens.primary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  SkillTree.roman(rank),
                  style: BarrageType.muted.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
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
    required this.cost,
    required this.owned,
    required this.lockReason,
    required this.affordable,
    required this.continues,
    required this.onBuy,
    required this.feel,
    this.celebrate,
  });

  final SkillNode node;

  /// Price now (crew nodes rise after a lost teammate).
  final int cost;
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
                    label: locked ? 'Locked' : 'Buy ${compactCoins(cost)}',
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

/// One-use power-ups: buy as many of each as you like, then fire them
/// from the fight HUD.
class _ItemsPanel extends StatelessWidget {
  const _ItemsPanel({
    required this.game,
    required this.celebrate,
    required this.onBuy,
  });

  final BackyardBarrageGame game;
  final _Purchase? celebrate;
  final ValueChanged<PowerUp> onBuy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final meta = game.meta;
    return ListView(
      key: const Key('shop-items'),
      padding: EdgeInsets.zero,
      children: [
        const Text('Items', style: BarrageType.heading),
        const Text(
          'One use each. Tap its button in a fight.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BarrageType.muted,
        ),
        SizedBox(height: tokens.space.sm),
        for (final item in PowerUp.values)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space.sm),
            child: _ItemRow(
              item: item,
              owned: meta.itemCount(item),
              cost: meta.itemCost(item),
              affordable: meta.canBuyItem(item),
              onBuy: () => onBuy(item),
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.cost,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final PowerUp item;
  final int cost;
  final int owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      key: Key('item-${item.name}'),
      padding: EdgeInsets.all(tokens.space.sm),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(
        children: [
          PowerUpBadge(item: item, size: 44),
          SizedBox(width: tokens.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  owned > 0 ? '${item.label}  ·  $owned owned' : item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BarrageType.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BarrageType.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.space.sm),
          PressScale(
            key: Key('buy-item-${item.name}'),
            enabled: affordable,
            onTap: onBuy,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.md,
                vertical: tokens.space.sm,
              ),
              decoration: BoxDecoration(
                gradient: affordable ? tokens.primaryGradient : null,
                color: affordable ? null : tokens.lockedFill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: CoinAmount(
                amount: cost,
                fontSize: 14,
                color: affordable ? tokens.onPrimary : tokens.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Team or Kid N by the Next wave button: a pill in that kid's color,
/// filled when picked.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        pressedScale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.fast,
          height: compact ? 40 : 44,
          padding: EdgeInsets.symmetric(horizontal: tokens.space.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: BarrageType.button.copyWith(
              fontSize: 14,
              color: selected ? BarrageColors.ink : tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
