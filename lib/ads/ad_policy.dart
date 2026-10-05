import 'ad_config.dart';

/// When an end-of-game interstitial is allowed.
class AdPolicy {
  const AdPolicy._();

  /// True only after the fight itself ran longer than two minutes, once
  /// per ending, and never while the fight is still going.
  static bool allows({
    required double fightSeconds,
    required bool alreadyShown,
    required bool inFight,
  }) {
    if (inFight || alreadyShown) return false;
    return fightSeconds > AdConfig.minFightSeconds;
  }
}
