/// Presents an interstitial when a run ends or the player leaves.
///
/// The game calls [onRunEnded] only when [AdPolicy] already allows it.
/// The returned flag is true when an interstitial actually showed, so the
/// session cooldown starts from that show.
abstract class EndAd {
  const EndAd();

  /// Consent and tracking prompts. Called once at app launch, before play.
  Future<void> prepare() async {}

  /// Show one interstitial. True when it was presented.
  Future<bool> onRunEnded({required double fightSeconds}) async => false;

  /// UMP privacy-options form. No-op until a message requires it.
  Future<void> showPrivacyOptions() async {}
}

/// Used by tests and any build that should not touch the ads SDK.
class NoEndAd extends EndAd {
  const NoEndAd();
}
