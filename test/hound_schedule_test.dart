import 'dart:math' as math;

import 'package:backyard_barrage/game/components/hound_component.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const runs = 4000;

  /// Share of runs where at least [n] hounds come within [seconds].
  double share(int wave, int n, double seconds, Difficulty difficulty) {
    final rng = math.Random(7);
    var hits = 0;
    for (var i = 0; i < runs; i++) {
      final times = HoundComponent.scheduleFor(
        wave: wave,
        difficulty: difficulty,
        rng: rng,
      );
      if (times.where((t) => t <= seconds).length >= n) hits++;
    }
    return hits / runs;
  }

  test('no hounds before wave 3', () {
    expect(share(2, 1, 1e9, Difficulty.hard), 0);
  });

  test('the roll: a fixed chance per wave, early, however fast you are', () {
    // Wave 6 on Easy: one in two plays meets a hound within 10 seconds.
    expect(share(6, 1, 10, Difficulty.easy), closeTo(0.5, 0.03));
    expect(share(6, 1, 10, Difficulty.normal), closeTo(0.6, 0.03));
    expect(share(3, 1, 10, Difficulty.normal), closeTo(0.18, 0.03));
    // Wave 10: one for sure, a second a quarter of the time.
    expect(share(10, 1, 10, Difficulty.normal), 1);
    expect(share(10, 2, 30, Difficulty.normal), closeTo(0.25, 0.03));
    // Wave 20: two for sure, a third a quarter of the time.
    expect(share(20, 2, 30, Difficulty.normal), 1);
    expect(share(20, 3, 40, Difficulty.normal), closeTo(0.25, 0.03));
  });

  test('lingering: one more every five minutes, up to four', () {
    // A wave you sit in for five minutes always brings one more.
    expect(share(6, 1, 300, Difficulty.easy), 1);
    expect(share(10, 2, 300, Difficulty.normal), 1);
    // Fifteen minutes: four in all.
    expect(share(10, 4, 900, Difficulty.normal), 1);
    expect(share(10, 5, 1e9, Difficulty.hard), 0, reason: 'never more');
    // Nothing extra in the first minute.
    expect(share(6, 2, 59, Difficulty.easy), 0);
  });

  test('no hound comes before four seconds', () {
    final rng = math.Random(2);
    for (var i = 0; i < 500; i++) {
      for (final t in HoundComponent.scheduleFor(
        wave: 25,
        difficulty: Difficulty.hard,
        rng: rng,
      )) {
        expect(t, greaterThanOrEqualTo(HoundComponent.earliest));
      }
    }
  });
}
