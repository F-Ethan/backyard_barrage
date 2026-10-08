import '../meta/difficulty.dart';

/// How the crew's health carries from one wave into the next.
///
/// Applies in both Campaign and Arcade. Easy and the first wave of a run
/// start everyone at full health. [carries] false skips it (tests).
///
/// | Difficulty | Standing kids | Knocked-out kids |
/// | --- | --- | --- |
/// | Easy | back to full | back at full |
/// | Normal | +1 HP | stay out |
/// | Hard | no heal | stay out |
///
/// Recovery skills add to that: Patch up adds [healBonus] HP to every
/// standing kid, and Second wind brings one knocked-out kid back at 1 HP.
class CrewCarry {
  const CrewCarry._();

  /// Heal for standing kids before skills.
  static int baseHeal(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 0,
    Difficulty.normal => 1,
    Difficulty.hard => 0,
  };

  /// HP for each kid going into the next wave. 0 means they sit it out.
  static List<int> next({
    required List<int> hp,
    required int maxHp,
    required Difficulty difficulty,
    required bool carries,
    int healBonus = 0,
    bool reviveOne = false,
  }) {
    if (!carries || difficulty == Difficulty.easy) {
      return List.filled(hp.length, maxHp);
    }
    final heal = baseHeal(difficulty) + healBonus;
    var reviveLeft = reviveOne;
    final next = <int>[];
    for (final now in hp) {
      if (now > 0) {
        next.add((now + heal).clamp(1, maxHp));
      } else if (reviveLeft) {
        reviveLeft = false;
        next.add(1);
      } else {
        next.add(0);
      }
    }
    return next;
  }
}
