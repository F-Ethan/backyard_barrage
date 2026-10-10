import 'ad_config.dart';

/// Where the game is offering an interstitial.
enum AdMoment {
  /// A boss wave was just cleared.
  bossBeaten,

  /// The crew went down.
  defeat,

  /// Any other break: an ordinary wave clear, or leaving to the menu.
  breakTime,
}

/// When an interstitial is allowed. Aim: about one every five waves.
///
/// - Never in a fight.
/// - Only after the player has won at least one wave since the last ad,
///   so losing wave 1 over and over never shows one.
/// - At least [AdConfig.interstitialMinGap] of fighting since the last ad
///   (or since the app opened), so a new player gets a few minutes in
///   first and a boss ad is not followed by a quick loss ad.
/// - Then: after every boss and every loss, and otherwise once
///   [AdConfig.interstitialWaves] waves have been won since the last ad.
class AdPolicy {
  const AdPolicy._();

  static bool allows({
    required bool inFight,
    required AdMoment moment,
    required Duration playSinceAd,
    required int wavesSinceAd,
  }) {
    if (inFight) return false;
    if (wavesSinceAd < 1) return false;
    if (playSinceAd < AdConfig.interstitialMinGap) return false;
    return switch (moment) {
      AdMoment.bossBeaten || AdMoment.defeat => true,
      AdMoment.breakTime => wavesSinceAd >= AdConfig.interstitialWaves,
    };
  }
}
