import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_theme.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'motion.dart';

/// A grown-up check before anything that spends money: a sum a young
/// child is unlikely to work out, with three answers to pick from. Returns
/// true only for the right answer.
Future<bool> askGrownUp(
  BuildContext context, {
  FeelBus? feel,
  math.Random? rng,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ParentalGate(feel: feel, rng: rng),
  );
  return ok ?? false;
}

class ParentalGate extends StatefulWidget {
  const ParentalGate({super.key, this.feel, this.rng});

  final FeelBus? feel;
  final math.Random? rng;

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  late final int a;
  late final int b;
  late final List<int> choices;

  @override
  void initState() {
    super.initState();
    final rng = widget.rng ?? math.Random();
    a = 6 + rng.nextInt(4); // 6–9
    b = 6 + rng.nextInt(4);
    final answer = a * b;
    final wrong = <int>{};
    while (wrong.length < 2) {
      final guess = answer + (rng.nextBool() ? 1 : -1) * (2 + rng.nextInt(7));
      if (guess != answer && guess > 0) wrong.add(guess);
    }
    choices = [answer, ...wrong]..shuffle(rng);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          type: MaterialType.transparency,
          child: SheetSurface(
            key: const Key('parental-gate'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ask a grown-up', style: BarrageType.title),
                SizedBox(height: tokens.space.xs),
                Text(
                  'What is $a × $b?',
                  key: const Key('parental-gate-question'),
                  style: BarrageType.heading,
                ),
                SizedBox(height: tokens.space.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: tokens.space.sm,
                  runSpacing: tokens.space.sm,
                  children: [
                    for (final choice in choices)
                      DraftImageButton(
                        key: Key('parental-gate-$choice'),
                        label: '$choice',
                        width: 96,
                        height: 52,
                        fontSize: 18,
                        feel: widget.feel,
                        onPressed: () =>
                            Navigator.of(context).pop(choice == a * b),
                      ),
                  ],
                ),
                SizedBox(height: tokens.space.sm),
                DraftImageButton(
                  key: const Key('parental-gate-cancel'),
                  label: 'Cancel',
                  back: true,
                  secondary: true,
                  width: 140,
                  height: 46,
                  feel: widget.feel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
