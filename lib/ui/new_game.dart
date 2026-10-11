import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'draft_button.dart';
import 'motion.dart';

/// What Arcade's New Game wipes, said the same way everywhere it is offered.
const String newGameWarning =
    'Start a new game at wave 1 with 0 coins, no skills, and no items? '
    'Your score goes back to 0. Your best score stays.';

/// Asks before Arcade's New Game. True when the player says yes.
Future<bool> confirmNewGame(BuildContext context, {FeelBus? feel}) async {
  final yes = await showDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) {
      final tokens = context.tokens;
      return ModalShell(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SheetSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New Game', style: BarrageType.title),
                SizedBox(height: tokens.space.sm),
                const Text(
                  newGameWarning,
                  key: Key('new-game-warning'),
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
                      key: const Key('new-game-yes'),
                      label: 'Yes, new game',
                      leadingIcon: Icons.restart_alt_rounded,
                      onPressed: () => Navigator.of(context).pop(true),
                      width: 220,
                      height: 52,
                      feel: feel,
                    ),
                    DraftImageButton(
                      key: const Key('new-game-cancel'),
                      label: 'Cancel',
                      back: true,
                      secondary: true,
                      onPressed: () => Navigator.of(context).pop(false),
                      width: 140,
                      height: 52,
                      feel: feel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return yes ?? false;
}

/// A small "New Game" pill for a card or a sheet.
class NewGameButton extends StatelessWidget {
  const NewGameButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.onDark = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  /// Light text for the blue home card.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ink = onDark ? tokens.onPrimary : tokens.primaryDeep;
    return Semantics(
      button: true,
      label: 'New Game',
      child: PressScale(
        pressedScale: 0.95,
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? tokens.space.sm : tokens.space.md,
            vertical: compact ? 3 : tokens.space.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restart_alt_rounded,
                size: compact ? 14 : 18,
                color: ink,
              ),
              const SizedBox(width: 4),
              Text(
                'New Game',
                style: BarrageType.button.copyWith(
                  fontSize: compact ? 12 : 14,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
