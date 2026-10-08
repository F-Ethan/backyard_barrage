import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../meta/power_up.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'motion.dart';

/// Glyph for each power-up. Material icons stand in until item art lands.
IconData powerUpIcon(PowerUp item) => switch (item) {
  PowerUp.frostArmor => Icons.shield_rounded,
  PowerUp.fortCracker => Icons.construction_rounded,
  PowerUp.freezeAll => Icons.ac_unit_rounded,
  PowerUp.powerThrow => Icons.bolt_rounded,
  PowerUp.bigSplat => Icons.blur_on_rounded,
  PowerUp.hotCocoa => Icons.local_cafe_rounded,
};

/// Fight HUD: one round button per power-up the wallet holds, with its
/// count. Items the player has none of do not show. A live item (armed for
/// the next throw, or Frost armor running) glows.
class PowerUpBar extends StatelessWidget {
  const PowerUpBar({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    final meta = game.meta;
    final shown = [
      for (final item in PowerUp.values)
        if (meta.itemCount(item) > 0 || game.isPowerUpLive(item)) item,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    // A column down the right edge that wraps into a second column to its
    // left on short screens, so six buttons never run off the bottom.
    return Wrap(
      key: const Key('power-up-bar'),
      direction: Axis.vertical,
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in shown)
          _PowerUpButton(
            item: item,
            count: meta.itemCount(item),
            live: game.isPowerUpLive(item),
            onTap: () => game.usePowerUp(item),
          ),
      ],
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  const _PowerUpButton({
    required this.item,
    required this.count,
    required this.live,
    required this.onTap,
  });

  final PowerUp item;
  final int count;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    return Semantics(
      button: true,
      label: '${item.label}, $count left',
      child: PressScale(
        key: Key('power-${item.name}'),
        enabled: count > 0 && !live,
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.medium,
          curve: motion.enter,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: live ? null : tokens.primaryGradient,
            color: live ? BarrageColors.charge : null,
            border: Border.all(color: tokens.surface, width: 2.5),
            boxShadow: live ? tokens.shadowPrimary : tokens.shadowSoft,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  powerUpIcon(item),
                  color: live ? BarrageColors.ink : tokens.onPrimary,
                  size: 24,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    key: Key('power-${item.name}-count'),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tokens.hairline),
                    ),
                    child: Text(
                      '$count',
                      style: BarrageType.button.copyWith(
                        fontSize: 12,
                        color: BarrageColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
