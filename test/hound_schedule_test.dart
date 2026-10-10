import 'dart:math' as math;

import 'package:backyard_barrage/game/components/hound_component.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = 60.0;
  const runs = 4000;

  /// Share of runs where at least [n] hounds come within [seconds].
  double share(int wave, int n, double seconds, Difficulty difficulty) {
    final rng = math.Random(7);
    var hits = 0;
    for (var i = 0; i < runs; i++) {
      final times = HoundComponent.scheduleFor(
        wave: wave,
        difficulty: difficulty,
        averageSeconds: d,
        rng: rng,
      );
      if (times.where((t) => t <= seconds).length >= n) hits++;
    }
    return hits / runs;
  }

  test('no hounds before wave 3', () {
    expect(share(2, 1, 1e9, Difficulty.hard), 0);
  });

  test('waves 3-9: the chance at an average pace, likelier if longer', () {
    expect(share(3, 1, d, Difficulty.normal), closeTo(0.18, 0.03));
    expect(share(6, 1, d, Difficulty.normal), closeTo(0.6, 0.03));
    expect(share(6, 1, 2 * d, Difficulty.normal), greaterThan(0.99));
    expect(share(6, 2, 1e9, Difficulty.hard), 0, reason: 'only one');
  });

  test('wave 10: one sure hound, a quarter chance of two, sure at 2x', () {
    expect(share(10, 1, d, Difficulty.normal), 1);
    expect(share(10, 2, d, Difficulty.normal), closeTo(0.25, 0.03));
    expect(share(10, 2, 2 * d, Difficulty.normal), 1);
    expect(share(10, 3, 1e9, Difficulty.normal), 0);
  });

  test('wave 20: two sure hounds and a quarter chance of a third', () {
    expect(share(20, 2, d, Difficulty.normal), 1);
    expect(share(20, 3, d, Difficulty.normal), closeTo(0.25, 0.03));
    expect(share(20, 3, 2 * d, Difficulty.normal), 1);
    expect(share(30, 3, d, Difficulty.normal), 1);
  });

  test('no hound comes before the earliest time', () {
    final rng = math.Random(2);
    for (var i = 0; i < 500; i++) {
      for (final t in HoundComponent.scheduleFor(
        wave: 25,
        difficulty: Difficulty.hard,
        averageSeconds: d,
        rng: rng,
      )) {
        expect(t, greaterThanOrEqualTo(HoundComponent.earliest));
      }
    }
  });
}
