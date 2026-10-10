import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../game/backyard_barrage_game.dart';
import '../meta/meta_state.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'power_up_ui.dart';

/// Between a wave clear and the shop: what the wave paid, then each kid's
/// hearts now and going into the next wave, with a heal or a revive.
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
    return ModalShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SheetSurface(
          key: const Key('wave-report'),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Wave ${game.wave} report',
                        style: BarrageType.title,
                      ),
                    ),
                    TagPill(child: CoinAmount(amount: meta.coins)),
                  ],
                ),
                SizedBox(height: tokens.space.sm),
                const Text('Rewards', style: BarrageType.heading),
                for (final line in game.waveRewards)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.space.xs),
                    child: Text(
                      line,
                      key: Key('report-reward-$line'),
                      style: BarrageType.body,
                    ),
                  ),
                SizedBox(height: tokens.space.md),
                const Text('Your crew', style: BarrageType.heading),
                for (var i = 0; i < next.length; i++)
                  _KidRow(
                    index: i,
                    now: i < game.players.length ? game.players[i].hp : 0,
                    next: next[i],
                    max: meta.kidMaxHp(i),
                    reviveCost: meta.reviveCost(i),
                    healCost: MetaState.healCostFor(game.wave),
                    coins: meta.coins,
                    feel: game.feel,
                    onRevive: () => _do(() => game.reviveKid(i)),
                    onHeal: () => _do(() => game.healKid(i)),
                  ),
                SizedBox(height: tokens.space.md),
                const Text('Your power-ups', style: BarrageType.heading),
                if (meta.items.isEmpty)
                  Text(
                    'None yet. Buy some in the shop, or scare off a hound.',
                    style: BarrageType.muted,
                  ),
                for (final entry in meta.items.entries)
                  Padding(
                    key: Key('report-item-${entry.key.name}'),
                    padding: EdgeInsets.only(top: tokens.space.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PowerUpBadge(item: entry.key, size: 32),
                        SizedBox(width: tokens.space.sm),
                        Expanded(
                          child: Text(
                            '${entry.key.label} ×${entry.value}: '
                            '${entry.key.detail}',
                            style: BarrageType.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: tokens.space.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: DraftImageButton(
                    key: const Key('report-continue'),
                    label: 'To the shop',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: game.openShopFromReport,
                    width: 220,
                    height: 54,
                    fontSize: 17,
                    feel: game.feel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KidRow extends StatelessWidget {
  const _KidRow({
    required this.index,
    required this.now,
    required this.next,
    required this.max,
    required this.reviveCost,
    required this.healCost,
    required this.coins,
    required this.feel,
    required this.onRevive,
    required this.onHeal,
  });

  final int index;
  final int now;
  final int next;
  final int max;
  final int reviveCost;
  final int healCost;
  final int coins;
  final FeelBus feel;
  final VoidCallback onRevive;
  final VoidCallback onHeal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final down = next <= 0;
    final heal = next - now;
    final summary = down
        ? 'Kid ${index + 1}: knocked out'
        : 'Kid ${index + 1}: $now ♥${heal > 0 ? ' +$heal' : ''} → $next ♥ of $max';
    final Widget action;
    if (down) {
      action = DraftImageButton(
        key: Key('report-revive-$index'),
        label: 'Revive · $reviveCost',
        leadingIcon: Icons.favorite_rounded,
        enabled: coins >= reviveCost,
        onPressed: onRevive,
        width: 170,
        height: 44,
        fontSize: 14,
        feel: feel,
      );
    } else if (next < max) {
      action = DraftImageButton(
        key: Key('report-heal-$index'),
        label: '+1 ♥ · $healCost',
        secondary: true,
        enabled: coins >= healCost,
        onPressed: onHeal,
        width: 150,
        height: 44,
        fontSize: 14,
        feel: feel,
      );
    } else {
      action = const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: tokens.space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              key: Key('report-kid-$index'),
              style: BarrageType.body.copyWith(
                color: down ? BarrageColors.ink.withValues(alpha: 0.6) : null,
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }
}
