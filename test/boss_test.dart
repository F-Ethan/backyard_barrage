import 'dart:math' as math;

import 'package:backyard_barrage/game/boss.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a boss closes every stage from wave 10', () {
    expect(
      [
        for (var w = 1; w <= 26; w++)
          if (BossRules.isBossWave(w)) w,
      ],
      [10, 15, 20, 25],
    );
  });

  test('the first boss comes alone; each one after brings one more', () {
    expect(BossRules.appearance(10), 1);
    expect(BossRules.supportFor(10), 0);
    expect(BossRules.supportFor(15), 1);
    expect(BossRules.supportFor(20), 2);
  });

  test('8 / 12 / 16 snowballs the first time, 25% more each return', () {
    expect(
      [for (final d in Difficulty.values) BossRules.hits(d, 1)],
      [8, 12, 16],
    );
    expect(
      [for (final d in Difficulty.values) BossRules.hits(d, 2)],
      [10, 15, 20],
    );
    expect(
      [for (final d in Difficulty.values) BossRules.hits(d, 3)],
      [13, 19, 25],
    );
  });

  test('damage skills do not melt a boss: health is counted in throws', () {
    expect(
      BossRules.hits(Difficulty.normal, 1, playerHits: 3),
      3 * BossRules.hits(Difficulty.normal, 1),
    );
  });

  test('a random boss, never the same one twice running', () {
    final rng = math.Random(4);
    BossType? last;
    final seen = <BossType>{};
    for (var i = 0; i < 40; i++) {
      final next = BossRules.pick(rng, last: last);
      expect(next, isNot(last));
      seen.add(next);
      last = next;
    }
    expect(seen, BossType.values.toSet());
  });

  test('ice spikes warn longer on easier modes', () {
    expect(
      BossRules.spikeWarnSeconds(Difficulty.easy),
      greaterThan(BossRules.spikeWarnSeconds(Difficulty.normal)),
    );
    expect(
      BossRules.spikeWarnSeconds(Difficulty.normal),
      greaterThan(BossRules.spikeWarnSeconds(Difficulty.hard)),
    );
    expect(BossRules.spikeWarnSeconds(Difficulty.hard), greaterThan(0.5));
  });

  test('every boss image is listed', () {
    expect(BossArt.all.toSet(), hasLength(BossArt.all.length));
    expect(BossArt.all, contains('characters/bosses/ogre/ogre_crash.png'));
    expect(
      BossArt.all,
      contains('characters/bosses/magma/magma_wave_push.png'),
    );
  });
}
