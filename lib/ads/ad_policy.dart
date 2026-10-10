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

/// When an interstitial is allowed: after every boss and every loss, and
/// otherwise once [AdConfig.interstitialEvery] of fighting has passed
/// since the last one. Never in a fight.
class AdPolicy {
  const AdPolicy._();

  /// [playSinceAd] is fight time since the last interstitial that actually
  /// showed (or since the app opened, when none has).
  static bool allows({
    required bool inFight,
    required AdMoment moment,
    required Duration playSinceAd,
    required bool anyShown,
  }) {
    if (inFight) return false;
    return switch (moment) {
      AdMoment.bossBeaten || AdMoment.defeat =>
        !anyShown || playSinceAd >= AdConfig.interstitialMinGap,
      AdMoment.breakTime => playSinceAd >= AdConfig.interstitialEvery,
    };
  }
}
