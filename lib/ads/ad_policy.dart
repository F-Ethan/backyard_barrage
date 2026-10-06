import 'ad_config.dart';

/// When an interstitial is allowed.
class AdPolicy {
  const AdPolicy._();

  /// True outside a fight, once [AdConfig.interstitialCooldown] has passed
  /// since the last interstitial that actually showed. A null
  /// [sinceLastShow] means none has shown this session.
  static bool allows({
    required bool inFight,
    required Duration? sinceLastShow,
  }) {
    if (inFight) return false;
    if (sinceLastShow == null) return true;
    return sinceLastShow >= AdConfig.interstitialCooldown;
  }
}
