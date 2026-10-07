import 'package:flutter/material.dart';

import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';

/// Winter / Summer segmented pill. The selected segment takes the season
/// gradient (cool blue / mint–teal) and slides between sides. Home, shop,
/// and defeat share it.
class SeasonToggle extends StatelessWidget {
  const SeasonToggle({
    super.key,
    required this.season,
    required this.onChanged,
    this.compact = false,
  });

  final Season season;
  final ValueChanged<Season> onChanged;
  final bool compact;

  static LinearGradient gradientFor(Season season) => switch (season) {
    Season.winter => const LinearGradient(
      colors: [BarrageColors.winterCool, BarrageColors.player],
    ),
    Season.summer => const LinearGradient(
      colors: [BarrageColors.summerMint, BarrageColors.summerTeal],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final segmentWidth = compact ? 84.0 : 100.0;
    final height = compact ? 36.0 : 42.0;
    final index = Season.values.indexOf(season);
    return Container(
      height: height + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.hairline),
      ),
      child: SizedBox(
        width: segmentWidth * Season.values.length,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: motion.medium,
              curve: motion.spring,
              left: segmentWidth * index,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: AnimatedContainer(
                duration: motion.medium,
                decoration: BoxDecoration(
                  gradient: gradientFor(season),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: tokens.shadowSoft,
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  for (final item in Season.values)
                    _SeasonSegment(
                      key: Key('season-${item.name}'),
                      season: item,
                      width: segmentWidth,
                      selected: season == item,
                      onTap: () => onChanged(item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonSegment extends StatelessWidget {
  const _SeasonSegment({
    super.key,
    required this.season,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final Season season;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final color = selected ? tokens.onPrimary : tokens.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                season == Season.winter
                    ? Icons.ac_unit_rounded
                    : Icons.wb_sunny_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: motion.fast,
                    style: BarrageType.button.copyWith(
                      fontSize: 14,
                      color: color,
                    ),
                    child: Text(season.label, maxLines: 1),
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
