import 'dart:math' as math;

import 'package:backyard_barrage/game/enemy_perks.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('perks start at wave 10 and grow to a 40% cap', () {
    expect(EnemyPerkRules.chance(9), 0);
    expect(EnemyPerkRules.chance(10), closeTo(0.10, 1e-9));
    expect(EnemyPerkRules.chance(20), closeTo(0.30, 1e-9));
    expect(EnemyPerkRules.chance(30), closeTo(0.40, 1e-9));
    expect(EnemyPerkRules.chance(60), closeTo(0.40, 1e-9));
  });

  test('levels 1, 2, 3 by tens; countdowns 20 / 15 / 10', () {
    expect([10, 19, 20, 29, 30, 50].map(EnemyPerkRules.level), [
      1,
      1,
      2,
      2,
      3,
      3,
    ]);
    expect(
      [for (final d in Difficulty.values) EnemyPerkRules.countdown(d)],
      [20, 15, 10],
    );
  });

  test('rolls match the chance; later waves stack distinct perks', () {
    final rng = math.Random(3);
    var carriers = 0;
    for (var i = 0; i < 4000; i++) {
      if (EnemyPerkRules.rollRival(10, Difficulty.normal, rng).isNotEmpty) {
        carriers++;
      }
    }
    expect(carriers / 4000, closeTo(0.10, 0.02));
    var most = 0;
    for (var i = 0; i < 4000; i++) {
      final perks = EnemyPerkRules.rollRival(35, Difficulty.normal, rng);
      expect(perks.map((p) => p.perk).toSet(), hasLength(perks.length));
      for (final held in perks) {
        expect(held.level, 3);
        if (held.perk.area) expect(held.countdown, 15);
      }
      if (perks.length > most) most = perks.length;
    }
    expect(most, 3);
    expect(
      EnemyPerkRules.rollRival(15, Difficulty.easy, rng).length,
      lessThan(2),
    );
  });

  test('bosses: none the first time, then one more per return', () {
    final rng = math.Random(1);
    expect(EnemyPerkRules.rollBoss(10, 1, Difficulty.hard, rng), isEmpty);
    expect(EnemyPerkRules.rollBoss(15, 2, Difficulty.hard, rng), hasLength(1));
    final many = EnemyPerkRules.rollBoss(40, 7, Difficulty.hard, rng);
    expect(many, hasLength(3));
    for (final held in many) {
      expect(EnemyPerkRules.bossPool, contains(held.perk));
    }
  });

  test('rival forts upgrade and multiply through the run', () {
    final rng = math.Random(5);
    expect(RivalFortRules.stage(4, rng), 1);
    expect(RivalFortRules.stage(25, rng), 3);
    for (var i = 0; i < 50; i++) {
      expect(RivalFortRules.stage(12, rng), inInclusiveRange(2, 3));
    }
    expect(RivalFortRules.extras(7, rng), 0);
    expect(RivalFortRules.extras(30, rng), 2);
  });
}
