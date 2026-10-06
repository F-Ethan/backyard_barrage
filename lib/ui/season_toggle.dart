import 'package:flutter/material.dart';

import '../seasons/season.dart';
import 'barrage_colors.dart';

/// Small Winter / Summer text toggle. Home, shop, and defeat share it.
class SeasonToggle extends StatelessWidget {
  const SeasonToggle({
    super.key,
    required this.season,
    required this.onChanged,
  });

  final Season season;
  final ValueChanged<Season> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in Season.values)
          _SeasonLink(
            key: Key('season-${item.name}'),
            label: item.label,
            selected: season == item,
            onTap: () => onChanged(item),
          ),
      ],
    );
  }
}

class _SeasonLink extends StatelessWidget {
  const _SeasonLink({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? BarrageColors.player : BarrageColors.inkMuted,
            decoration: selected ? TextDecoration.underline : null,
            decorationColor: BarrageColors.player,
          ),
        ),
      ),
    );
  }
}
