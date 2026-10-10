import 'package:flutter/material.dart';

import '../game/crew_snapshot.dart';
import '../game/kid_colors.dart';
import '../game/wave_reward.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'power_up_ui.dart';
import 'ui_assets.dart';

/// The skill menu's frame for the wave report and the defeat summary: a
/// header row, a body that scrolls, and a footer that never does, so the
/// next button is always in reach.
class ReportSheet extends StatelessWidget {
  const ReportSheet({
    super.key,
    required this.title,
    required this.body,
    required this.footer,
    this.trailing = const [],
  });

  final String title;

  /// Pills at the right of the title row (coins, mode).
  final List<Widget> trailing;
  final List<Widget> body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ModalShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final insetX = (constraints.maxWidth * 0.05).clamp(24.0, 64.0);
              final insetY = (constraints.maxHeight * 0.05).clamp(12.0, 24.0);
              final compact = constraints.maxHeight < 380;
              return SheetSurface(
                padding: EdgeInsets.fromLTRB(insetX, insetY, insetX, insetY),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BarrageType.title.copyWith(
                              fontSize: compact ? 22 : 26,
                            ),
                          ),
                        ),
                        for (final pill in trailing) ...[
                          SizedBox(width: tokens.space.sm),
                          pill,
                        ],
                      ],
                    ),
                    SizedBox(height: tokens.space.sm),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: body,
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.space.sm),
                    footer,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A section title inside a [ReportSheet].
class ReportSection extends StatelessWidget {
  const ReportSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.space.md, bottom: tokens.space.sm),
      child: Text(title, style: BarrageType.heading),
    );
  }
}

/// Pills that wrap left to right.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: tokens.space.sm,
      runSpacing: tokens.space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// One pill: an icon, a big value, and a small caption under it.
class ReportPill extends StatelessWidget {
  const ReportPill({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    this.tint,
  });

  final Widget icon;
  final String value;
  final String caption;

  /// Value color and border; blue by default.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = this.tint ?? tokens.primaryDeep;
    return TagPill(
      borderColor: tint.withValues(alpha: 0.35),
      padding: EdgeInsets.fromLTRB(
        tokens.space.sm,
        tokens.space.xs,
        tokens.space.md + 2,
        tokens.space.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 32, child: Center(child: icon)),
          SizedBox(width: tokens.space.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: BarrageType.heading.copyWith(fontSize: 16, color: tint),
              ),
              Text(caption, style: BarrageType.muted.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A reward as a pill: the coin or the power-up's own art.
class RewardPill extends StatelessWidget {
  const RewardPill({super.key, required this.reward});

  final WaveReward reward;

  @override
  Widget build(BuildContext context) {
    final item = reward.item;
    return ReportPill(
      icon: item == null
          ? Image.asset(UiAssets.coin, width: 28, height: 28)
          : PowerUpBadge(item: item, size: 30),
      value: reward.label,
      caption: reward.source,
    );
  }
}

/// A kid's state at one moment, in a pill: hearts and shield on top,
/// their own upgrade counts (attack, defense, crew) under them.
class KidStatusPill extends StatelessWidget {
  const KidStatusPill({
    super.key,
    required this.state,
    required this.caption,
    this.tint,
  });

  final KidState state;
  final String caption;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final down = state.hp <= 0;
    final ink = down ? tokens.inkMuted : tokens.ink;
    final value = BarrageType.heading.copyWith(fontSize: 15, color: ink);
    final up = state.upgrades;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.12) ?? tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (tint ?? tokens.hairline).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space.sm + 2,
          vertical: tokens.space.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!state.inCrew)
              Text('Not in crew', style: value)
            else ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    down ? UiAssets.heartEmpty : UiAssets.heart,
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    down ? 'Down' : '${state.hp}/${state.maxHp}',
                    style: value,
                  ),
                  if (state.shield > 0 && !down) ...[
                    SizedBox(width: tokens.space.sm),
                    Icon(Icons.shield_rounded, size: 18, color: tokens.primary),
                    const SizedBox(width: 2),
                    Text('${state.shield}', style: value),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UpgradeChip(kind: UpgradeKind.attack, count: up.attack),
                  const SizedBox(width: 3),
                  UpgradeChip(kind: UpgradeKind.defense, count: up.defense),
                  const SizedBox(width: 3),
                  UpgradeChip(kind: UpgradeKind.crew, count: up.crew),
                ],
              ),
            ],
            Text(caption, style: BarrageType.muted.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// A kid's picture in their color: standing, or knocked flat when down.
class KidPortrait extends StatelessWidget {
  const KidPortrait({super.key, required this.kid, this.down = false});

  final int kid;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final color = KidColors.of(kid);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 3),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: Opacity(
          opacity: down ? 0.55 : 1,
          // The art has room around the kid: zoom to the head and body.
          child: Transform.scale(
            scale: down ? 1.4 : 1.9,
            alignment: down ? Alignment.center : const Alignment(0, -0.55),
            child: Image.asset(
              'assets/images/${SeasonAssets.crewDir(kid)}'
              '${down ? 'kid_ko_512.png' : 'kid_idle_512.png'}',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// A kid's report card: picture and name in their color, knockouts, their
/// state [now] → the state they start the next wave in ([next]), and a
/// button (heal or revive) at the right. The wave report and the defeat
/// summary both use it.
class KidCard extends StatelessWidget {
  const KidCard({
    super.key,
    required this.kid,
    required this.knockouts,
    required this.now,
    required this.next,
    this.nowCaption = 'Wave end',
    this.nextCaption = 'Next wave',
    this.action,
  });

  final int kid;
  final int knockouts;
  final KidState now;
  final KidState next;
  final String nowCaption;
  final String nextCaption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = KidColors.of(kid);
    return Container(
      margin: EdgeInsets.only(bottom: tokens.space.sm),
      padding: EdgeInsets.all(tokens.space.sm),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: tokens.radii.cardAll,
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          KidPortrait(kid: kid, down: now.hp <= 0),
          SizedBox(width: tokens.space.md),
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  KidColors.nameOf(kid),
                  style: BarrageType.heading.copyWith(
                    color: KidColors.deepOf(kid),
                  ),
                ),
                Text(
                  '$knockouts KO${knockouts == 1 ? '' : 's'}',
                  key: Key('report-kos-$kid'),
                  style: BarrageType.muted,
                ),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: tokens.space.sm,
              runSpacing: tokens.space.xs,
              children: [
                KidStatusPill(
                  key: Key('report-now-$kid'),
                  state: now,
                  caption: nowCaption,
                ),
                Icon(Icons.arrow_forward_rounded, color: tokens.inkMuted),
                KidStatusPill(
                  key: Key('report-next-$kid'),
                  state: next,
                  caption: nextCaption,
                  tint: color,
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// The three kinds of a kid's own upgrades.
enum UpgradeKind {
  attack('Attack', Icons.flash_on_rounded, Color(0xFFE67E22)),
  defense('Defense', Icons.health_and_safety_rounded, Color(0xFF3D7CFF)),
  crew('Crew', Icons.groups_rounded, Color(0xFF16A085));

  const UpgradeKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// A tiny icon and count: how many upgrades of one kind a kid has.
class UpgradeChip extends StatelessWidget {
  const UpgradeChip({super.key, required this.kind, required this.count});

  final UpgradeKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = kind.color;
    return Semantics(
      label: '${kind.label} upgrades: $count',
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 1, 6, 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: count > 0 ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind.icon,
              size: 14,
              color: count > 0 ? color : color.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: BarrageType.heading.copyWith(
                fontSize: 12,
                color: count > 0 ? BarrageColors.ink : BarrageColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart color for anything that reads as "lost".
const Color lossTint = BarrageColors.heart;
