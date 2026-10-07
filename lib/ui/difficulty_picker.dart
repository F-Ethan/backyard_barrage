import 'package:flutter/material.dart';

import '../meta/difficulty.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'motion.dart';

/// Easy / Normal / Hard pills. Lives on the home screen only, so the mode
/// cannot change in the middle of a run.
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in Difficulty.values)
          Padding(
            padding: EdgeInsets.only(
              right: mode == Difficulty.values.last ? 0 : tokens.space.xs,
            ),
            child: SizedBox(
              width: compact ? 78 : 92,
              child: _DifficultyChip(
                key: Key('difficulty-${mode.name}'),
                label: mode.label,
                selected: value == mode,
                height: compact ? 38 : 42,
                onTap: () => onChanged(mode),
              ),
            ),
          ),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 42,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.medium,
          curve: motion.enter,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? tokens.primaryGradient : null,
            color: selected ? null : tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0x00000000) : tokens.hairline,
              width: 1.5,
            ),
            boxShadow: selected ? tokens.shadowPrimary : null,
          ),
          child: Text(
            label,
            style: BarrageType.button.copyWith(
              color: selected ? tokens.onPrimary : tokens.ink,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
