import 'ad_config.dart';

/// When an end-of-game interstitial is allowed.
class AdPolicy {
  const AdPolicy._();

  /// True after two minutes of fight time or three cleared waves,
  /// whichever comes first. Once per run, and never while the fight
  /// is still going.
  static bool allows({
    required double fightSeconds,
    required int wavesCleared,
    required bool alreadyShown,
    required bool inFight,
  }) {
    if (inFight || alreadyShown) return false;
    return fightSeconds > AdConfig.minFightSeconds ||
        wavesCleared >= AdConfig.minWavesBeforeAd;
  }
}
