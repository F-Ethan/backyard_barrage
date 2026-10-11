import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../meta/power_up.dart';
import '../game/kid_colors.dart';
import '../game/crew_snapshot.dart';
import '../meta/meta_state.dart';
import '../meta/play_mode.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'power_up_ui.dart';
import 'new_game.dart';
import 'report_kit.dart';
import 'season_toggle.dart';
import 'ui_assets.dart';

class DefeatOverlay extends StatefulWidget {
  const DefeatOverlay({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<DefeatOverlay> createState() => _DefeatOverlayState();
}

class _DefeatOverlayState extends State<DefeatOverlay> {
  /// Start over was tapped once; the buttons ask to confirm.
  bool _confirmStartOver = false;

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
    final checkpoint = meta.mode == PlayMode.campaign;
    final result = game.lastDefeat;
    final retryWave = result?.wave ?? 1;
    final stage = MetaState.stageOf(retryWave);
    final lostOn = game.wave;
    final before = game.defeatBefore;
    final after = game.defeatAfter;
    final changes = before == null || after == null
        ? const <_Change>[]
        : _Change.between(before, after);
    return ReportSheet(
      key: const Key('defeat-sheet'),
      title: 'Crew down',
      trailing: [
        TagPill(
          child: Text(
            meta.mode.label.toUpperCase(),
            style: BarrageType.overline.copyWith(color: tokens.primaryDeep),
          ),
        ),
        TagPill(child: CoinAmount(amount: meta.coins)),
      ],
      body: [
        Text(
          checkpoint
              ? 'Back to wave $retryWave, the start of stage $stage. '
                    'Your build from then is back, everything bought '
                    'since is refunded, and half the coins earned '
                    'since are lost.'
              : 'Back to wave 1. Skills and potions reset, and half the '
                    'coins earned this run are lost.',
          key: const Key('defeat-rule'),
          style: BarrageType.body,
        ),
        const ReportSection('Wave progress'),
        PillRow(
          children: [
            ReportPill(
              icon: Icon(Icons.flag_rounded, color: lossTint),
              value: 'Wave $lostOn',
              caption: 'Crew went down',
              tint: lossTint,
            ),
            Icon(Icons.arrow_forward_rounded, color: tokens.inkMuted),
            ReportPill(
              key: const Key('defeat-progress'),
              icon: Icon(Icons.replay_rounded, color: tokens.primary),
              value: 'Wave $retryWave',
              caption: checkpoint
                  ? 'Progress set back to stage $stage'
                  : 'Progress set back',
            ),
          ],
        ),
        if (before != null) ...[
          const ReportSection('Your crew'),
          for (var i = 0; i < before.kids.length; i++)
            KidCard(
              key: Key('defeat-kid-$i'),
              kid: before.kids[i].kid,
              knockouts: i < game.kidKos.length ? game.kidKos[i] : 0,
              now: before.kids[i],
              next: KidState.fresh(meta, before.kids[i].kid),
              nowCaption: 'Went down',
              nextCaption: 'At the retry',
            ),
        ],
        const ReportSection('Losses'),
        PillRow(
          children: [
            if ((result?.coinsLost ?? 0) > 0)
              ReportPill(
                key: const Key('defeat-lost'),
                icon: Image.asset(UiAssets.coin, width: 28, height: 28),
                value: '-${compactCoins(result?.coinsLost ?? 0)}',
                caption: 'Coins lost',
                tint: lossTint,
              ),
            if (game.lastScorePenalty > 0)
              ReportPill(
                key: const Key('defeat-penalty'),
                icon: Icon(Icons.star_rounded, color: lossTint),
                value: '-${game.lastScorePenalty}',
                caption: 'Score',
                tint: lossTint,
              ),
            for (final change in changes.where((c) => c.amount < 0))
              _ChangePill(change: change),
          ],
        ),
        if ((result?.refunded ?? 0) > 0 ||
            changes.any((c) => c.amount > 0)) ...[
          const ReportSection('Back to you'),
          PillRow(
            children: [
              if (result != null && result.refunded > 0)
                ReportPill(
                  key: const Key('defeat-refund'),
                  icon: Image.asset(UiAssets.coin, width: 28, height: 28),
                  value: '+${compactCoins(result.refunded)}',
                  caption: 'Refunded',
                ),
              for (final change in changes.where((c) => c.amount > 0))
                _ChangePill(change: change),
            ],
          ),
        ],
        const ReportSection('Your run'),
        PillRow(
          children: [
            ReportPill(
              icon: Icon(Icons.check_circle_rounded, color: tokens.primary),
              value: '$cleared',
              caption: 'Waves cleared',
            ),
            if (meta.mode.showsScore) ...[
              ReportPill(
                key: const Key('defeat-score'),
                icon: Icon(Icons.star_rounded, color: tokens.coin),
                value: '${meta.score}',
                caption: '${difficulty.label} score',
              ),
              ReportPill(
                key: const Key('defeat-best-score'),
                icon: Icon(Icons.emoji_events_rounded, color: tokens.coin),
                value: '${meta.bestScore}',
                caption: 'Best',
              ),
            ] else
              ReportPill(
                icon: Icon(Icons.emoji_events_rounded, color: tokens.coin),
                value: '${meta.bestWave}',
                caption: '${difficulty.label} best',
              ),
          ],
        ),
        if (Season.choosable) ...[
          SizedBox(height: tokens.space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: SeasonToggle(season: meta.season, onChanged: _setSeason),
          ),
        ],
        SizedBox(height: tokens.space.sm),
      ],
      footer: _confirmStartOver
          ? _StartOverConfirm(
              game: game,
              onCancel: () => setState(() => _confirmStartOver = false),
            )
          : Row(
              children: [
                DraftImageButton(
                  key: const Key('back-to-menu'),
                  label: 'Menu',
                  back: true,
                  secondary: true,
                  leadingIcon: Icons.home_rounded,
                  onPressed: game.exitToMenu,
                  width: 120,
                  height: 52,
                  feel: game.feel,
                ),
                if (checkpoint) ...[
                  SizedBox(width: tokens.space.sm),
                  DraftImageButton(
                    key: const Key('start-over'),
                    label: 'New Game',
                    secondary: true,
                    leadingIcon: Icons.restart_alt_rounded,
                    onPressed: () => setState(() => _confirmStartOver = true),
                    width: 150,
                    height: 52,
                    feel: game.feel,
                  ),
                ],
                const Spacer(),
                // Coins left over: offer to spend them before the retry.
                DraftImageButton(
                  key: const Key('open-skills'),
                  label: meta.coins > 0 ? 'Spend coins' : 'Skills',
                  secondary: meta.coins <= 0,
                  leadingIcon: Icons.auto_awesome_rounded,
                  onPressed: game.openSkillTree,
                  width: 170,
                  height: 52,
                  feel: game.feel,
                ),
                SizedBox(width: tokens.space.sm),
                DraftImageButton(
                  key: const Key('retry'),
                  label: checkpoint ? 'Retry stage $stage' : 'Retry',
                  leadingIcon: Icons.replay_rounded,
                  onPressed: game.retryFromDefeat,
                  width: 190,
                  height: 52,
                  fontSize: 17,
                  feel: game.feel,
                ),
              ],
            ),
    );
  }
}

/// Second step of Start over: says what it wipes, then Yes / Cancel.
class _StartOverConfirm extends StatelessWidget {
  const _StartOverConfirm({required this.game, required this.onCancel});

  final BackyardBarrageGame game;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          newGameWarning,
          key: const Key('start-over-warning'),
          style: BarrageType.body,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.space.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.space.md,
          runSpacing: tokens.space.sm,
          children: [
            DraftImageButton(
              key: const Key('start-over-yes'),
              label: 'Yes, new game',
              leadingIcon: Icons.restart_alt_rounded,
              onPressed: game.startOverFromDefeat,
              width: 220,
              height: 56,
              feel: game.feel,
            ),
            DraftImageButton(
              key: const Key('start-over-cancel'),
              label: 'Cancel',
              back: true,
              secondary: true,
              onPressed: onCancel,
              width: 140,
              height: 56,
              feel: game.feel,
            ),
          ],
        ),
      ],
    );
  }
}

/// One thing a loss changed: a kid's upgrades of one kind, the team's
/// shared skills, a kid leaving the crew, or a power-up. Negative is lost,
/// positive came back.
class _Change {
  const _Change({
    required this.key,
    required this.amount,
    required this.label,
    required this.caption,
    this.kind,
    this.item,
    this.icon,
  });

  final String key;
  final int amount;
  final String label;
  final String caption;
  final UpgradeKind? kind;
  final PowerUp? item;
  final IconData? icon;

  static List<_Change> between(CrewSnapshot before, CrewSnapshot after) {
    final changes = <_Change>[];
    for (var i = 0; i < before.kids.length && i < after.kids.length; i++) {
      final name = KidColors.nameOf(before.kids[i].kid);
      if (!after.kids[i].inCrew) {
        changes.add(
          _Change(
            key: 'defeat-left-$i',
            amount: -1,
            label: '$name left',
            caption: 'Not in the crew yet',
            icon: Icons.person_remove_rounded,
          ),
        );
        continue;
      }
      final was = before.kids[i].upgrades;
      final now = after.kids[i].upgrades;
      for (final (kind, a, b) in [
        (UpgradeKind.attack, was.attack, now.attack),
        (UpgradeKind.defense, was.defense, now.defense),
        (UpgradeKind.crew, was.crew, now.crew),
      ]) {
        if (a == b) continue;
        changes.add(
          _Change(
            key: 'defeat-skill-$i-${kind.name}',
            amount: b - a,
            label: '${kind.label} skills',
            caption: name,
            kind: kind,
          ),
        );
      }
    }
    if (after.teamRanks != before.teamRanks) {
      changes.add(
        _Change(
          key: 'defeat-skill-team',
          amount: after.teamRanks - before.teamRanks,
          label: 'Team skills',
          caption: 'Whole crew',
          icon: Icons.auto_awesome_rounded,
        ),
      );
    }
    for (final item in PowerUp.values) {
      final delta = (after.items[item] ?? 0) - (before.items[item] ?? 0);
      if (delta == 0) continue;
      changes.add(
        _Change(
          key: 'defeat-item-${item.name}',
          amount: delta,
          label: item.label,
          caption: delta > 0 ? 'Back' : 'Lost',
          item: item,
        ),
      );
    }
    return changes;
  }
}

/// A [_Change] as a pill: red for lost, blue for back.
class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.change});

  final _Change change;

  @override
  Widget build(BuildContext context) {
    final lost = change.amount < 0;
    final item = change.item;
    final kind = change.kind;
    final Widget icon = item != null
        ? PowerUpBadge(item: item, size: 30)
        : Icon(
            kind?.icon ?? change.icon,
            color: kind?.color ?? (lost ? lossTint : null),
          );
    final sign = lost ? '-' : '+';
    final count = change.amount.abs();
    return ReportPill(
      key: Key(change.key),
      icon: icon,
      value: change.key.startsWith('defeat-left')
          ? change.label
          : '$sign$count ${change.label}',
      caption: change.caption,
      tint: lost ? lossTint : null,
    );
  }
}
