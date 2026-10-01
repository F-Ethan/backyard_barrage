import 'package:flutter/material.dart';

import '../seasons/season.dart';

class SeasonChip extends StatelessWidget {
  const SeasonChip({
    super.key,
    required this.season,
    required this.selected,
    required this.onTap,
  });

  final Season season;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('chip-${season.name}-$selected'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 128,
        height: 48,
        child: Image.asset(
          SeasonAssets.chipAsset(season, selected: selected),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
