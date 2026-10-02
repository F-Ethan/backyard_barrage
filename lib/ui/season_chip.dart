import 'package:flutter/material.dart';

import '../seasons/season.dart';
import 'ui_kit.dart';

/// Season pill from the v2 kit. The art is the glyph; Flutter draws the name
/// on the label well the generator left for text.
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
    final kit = UiKitScope.of(context);
    return GestureDetector(
      key: ValueKey('chip-${season.name}-$selected'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 156,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                kit.chip(season.name, selected: selected),
                fit: BoxFit.fill,
              ),
            ),
            if (kit.modern)
              Padding(
                padding: const EdgeInsets.only(left: 52, right: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    season.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? kit.onPrimary : kit.inkMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
