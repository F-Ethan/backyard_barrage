import 'dart:math' as math;

import '../meta/difficulty.dart';
import '../meta/power_up.dart';

/// Skills and potions a rival can carry into a wave (from wave 10).
enum EnemyPerk {
  /// Blocks [EnemyPerkRules] level hits, shown as a shield badge.
  shield(area: false, item: null),

  /// Heals itself the first time it is hurt.
  cocoa(area: false, item: PowerUp.hotCocoa),

  /// A permanently quicker windup.
  quickHands(area: false, item: null),

  /// Its next throws burst where they land and hit everyone nearby.
  bigSplat(area: false, item: PowerUp.bigSplat),

  /// Its next throw knocks a fort flat.
  fortCracker(area: false, item: PowerUp.fortCracker),

  /// After a countdown, freezes the whole crew.
  freezeAll(area: true, item: PowerUp.freezeAll),

  /// After a countdown, heals every rival.
  teamCocoa(area: true, item: PowerUp.hotCocoa),

  /// After a countdown, puts every rival in Frost armor.
  teamArmor(area: true, item: PowerUp.frostArmor);

  const EnemyPerk({required this.area, required this.item});

  /// Fires for the whole side after a countdown that knocking this rival
  /// out cancels.
  final bool area;

  /// The power-up it looks like (its badge), and what it may drop. Null
  /// for skills, which drop nothing.
  final PowerUp? item;
}

/// One perk on one rival, at a level, with what is left of it.
class HeldPerk {
  HeldPerk(this.perk, this.level, {double? countdown})
    : uses = switch (perk) {
        EnemyPerk.bigSplat => level,
        _ => 1,
      },
      countdown = countdown ?? 0;

  final EnemyPerk perk;

  /// 1, 2, or 3: stronger later in the run.
  final int level;

  /// Throws or triggers left. 0 means spent.
  int uses;

  /// Seconds until an area perk fires.
  double countdown;

  bool get spent => uses <= 0;
}

/// When rivals carry perks and how strong they are.
abstract final class EnemyPerkRules {
  /// First wave a rival can carry a perk.
  static const int firstWave = 10;

  /// Chance one rival carries perks on [wave]: 10% at wave 10, +2% a wave,
  /// at most 40%.
  static double chance(int wave) {
    if (wave < firstWave) return 0;
    return math.min(0.4, 0.10 + 0.02 * (wave - firstWave));
  }

  /// Perk strength: 1 on waves 10–19, 2 on 20–29, 3 from 30.
  static int level(int wave) => math.min(3, math.max(1, wave ~/ 10));

  /// Seconds an area perk counts down before it fires.
  static double countdown(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 20,
    Difficulty.normal => 15,
    Difficulty.hard => 10,
  };

  /// Seconds the crew stays frozen when a rival's Freeze all goes off.
  static const double freezeSeconds = 1.5;

  /// Seconds a rival's team Frost armor lasts.
  static const double armorSeconds = 3;

  /// Quick hands: windup multiplier by level.
  static double windupScale(int level) => switch (level) {
    1 => 0.85,
    2 => 0.75,
    _ => 0.65,
  };

  /// Chance an unused potion drops for the crew when its rival goes down.
  static const double dropChance = 0.5;

  /// Perks the bosses can carry: no throw-changing ones, since their
  /// throws already burst.
  static const bossPool = [
    EnemyPerk.shield,
    EnemyPerk.cocoa,
    EnemyPerk.freezeAll,
    EnemyPerk.teamCocoa,
    EnemyPerk.teamArmor,
  ];

  /// Perks for one ordinary rival on [wave] (often none). Waves 20+ can
  /// roll a second, 30+ a third, all different.
  static List<HeldPerk> rollRival(
    int wave,
    Difficulty difficulty,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= chance(wave)) return const [];
    final lv = level(wave);
    var count = 1;
    if (lv >= 2 && rng.nextDouble() < 0.25) count++;
    if (lv >= 3 && rng.nextDouble() < 0.25) count++;
    return _pick(EnemyPerk.values, count, lv, difficulty, rng);
  }

  /// Perks for a boss: none the first time, then one more each time a
  /// boss returns (at most three).
  static List<HeldPerk> rollBoss(
    int wave,
    int appearance,
    Difficulty difficulty,
    math.Random rng,
  ) {
    final count = math.min(3, math.max(0, appearance - 1));
    return _pick(bossPool, count, level(wave), difficulty, rng);
  }

  static List<HeldPerk> _pick(
    List<EnemyPerk> pool,
    int count,
    int lv,
    Difficulty difficulty,
    math.Random rng,
  ) {
    final options = List.of(pool)..shuffle(rng);
    return [
      for (final perk in options.take(count))
        HeldPerk(perk, lv, countdown: perk.area ? countdown(difficulty) : null),
    ];
  }
}

/// How the rival side's forts grow through the run.
abstract final class RivalFortRules {
  /// The main rival fort's stage on [wave]: 1 early, sometimes 2 from wave
  /// 5, 2 or 3 from wave 10, 3 from wave 20.
  static int stage(int wave, math.Random rng) {
    if (wave < 5) return 1;
    if (wave < 10) return rng.nextDouble() < 0.3 ? 2 : 1;
    if (wave < 20) return rng.nextDouble() < 0.4 ? 3 : 2;
    return 3;
  }

  /// Extra rival forts on [wave]: maybe one from wave 8, one sure and
  /// maybe a second from wave 15, two from wave 25.
  static int extras(int wave, math.Random rng) {
    if (wave < 8) return 0;
    if (wave < 15) return rng.nextDouble() < 0.25 ? 1 : 0;
    if (wave < 25) return rng.nextDouble() < 0.25 ? 2 : 1;
    return 2;
  }
}
