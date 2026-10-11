import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../game/crew_snapshot.dart';
import '../meta/meta_state.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'power_up_ui.dart';
import 'report_kit.dart';

/// Between a wave clear and the skills: what the wave paid, then a card per
/// kid with their knockouts and their state now → going into the next wave,
/// with a heal or a revive. Laid out like the skill menu, with the next
/// button fixed at the bottom.
class WaveReport extends StatefulWidget {
  const WaveReport({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  State<WaveReport> createState() => _WaveReportState();
}

class _WaveReportState extends State<WaveReport> {
  void _do(bool Function() purchase) {
    if (purchase()) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final meta = game.meta;
    final tokens = context.tokens;
    final next = game.nextCrewHp;
    final healCost = MetaState.healCostFor(game.wave);
    return ReportSheet(
      key: const Key('wave-report'),
      title: 'Wave ${game.wave} report',
      trailing: [
        TagPill(child: CoinAmount(amount: meta.coins)),
        KitIconButton(
          key: const Key('report-settings'),
          kind: UiIconKind.settings,
          semanticLabel: 'Settings',
          size: 44,
          feel: game.feel,
          onPressed: game.openSettings,
        ),
      ],
      body: [
        const ReportSection('Rewards'),
        PillRow(
          children: [
            for (final (i, reward) in game.waveRewards.indexed)
              RewardPill(key: Key('report-reward-$i'), reward: reward),
          ],
        ),
        const ReportSection('Your crew'),
        for (var i = 0; i < next.length; i++)
          KidCard(
            key: Key('report-kid-$i'),
            kid: meta.kidAt(i),
            knockouts: game.kidKos[i],
            now: KidState(
              kid: meta.kidAt(i),
              hp: i < game.players.length ? game.players[i].hp : 0,
              maxHp: meta.kidMaxHp(meta.kidAt(i)),
              shield: i < game.players.length ? game.players[i].shieldHits : 0,
              upgrades: meta.kidUpgrades(meta.kidAt(i)),
            ),
            next: KidState(
              kid: meta.kidAt(i),
              hp: next[i],
              maxHp: meta.kidMaxHp(meta.kidAt(i)),
              shield: meta.kidShield(meta.kidAt(i)),
              upgrades: meta.kidUpgrades(meta.kidAt(i)),
            ),
            action: _action(i, next[i], meta, healCost),
          ),
        const ReportSection('Your power-ups'),
        if (meta.items.isEmpty)
          Text(
            'None yet. Buy some in the skills, or scare off a hound.',
            style: BarrageType.muted,
          )
        else
          PillRow(
            children: [
              for (final entry in meta.items.entries)
                ReportPill(
                  key: Key('report-item-${entry.key.name}'),
                  icon: PowerUpBadge(item: entry.key, size: 30),
                  value: '×${entry.value}',
                  caption: entry.key.label,
                ),
            ],
          ),
        SizedBox(height: tokens.space.sm),
      ],
      footer: Align(
        alignment: Alignment.centerRight,
        child: DraftImageButton(
          key: const Key('report-continue'),
          label: 'To the skills',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: game.openShopFromReport,
          width: 220,
          height: 52,
          fontSize: 17,
          feel: game.feel,
        ),
      ),
    );
  }

  Widget? _action(int i, int next, MetaState meta, int healCost) {
    final game = widget.game;
    if (next <= 0) {
      final cost = meta.reviveCost(meta.kidAt(i));
      return DraftImageButton(
        key: Key('report-revive-$i'),
        label: 'Revive · $cost',
        leadingIcon: Icons.favorite_rounded,
        enabled: meta.coins >= cost,
        onPressed: () => _do(() => game.reviveKid(i)),
        width: 160,
        height: 44,
        fontSize: 14,
        feel: game.feel,
      );
    }
    if (next < meta.kidMaxHp(meta.kidAt(i))) {
      return DraftImageButton(
        key: Key('report-heal-$i'),
        label: 'Heal · $healCost',
        leadingIcon: Icons.favorite_rounded,
        secondary: true,
        enabled: meta.coins >= healCost,
        onPressed: () => _do(() => game.healKid(i)),
        width: 140,
        height: 44,
        fontSize: 14,
        feel: game.feel,
      );
    }
    return null;
  }
}
