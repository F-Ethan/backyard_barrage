/// Presents at most one interstitial after a run ends.
///
/// The game calls [onRunEnded] only when [AdPolicy] already allows it.
abstract class EndAd {
  const EndAd();

  /// Consent and tracking prompts. Called once at app launch, before play.
  Future<void> prepare() async {}

  /// The run is over and the policy allowed one ad.
  Future<void> onRunEnded({required double fightSeconds}) async {}

  /// UMP privacy-options form. No-op until a message requires it.
  Future<void> showPrivacyOptions() async {}
}

/// Used by tests and any build that should not touch the ads SDK.
class NoEndAd extends EndAd {
  const NoEndAd();
}
