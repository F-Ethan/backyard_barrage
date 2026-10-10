import 'package:flutter/foundation.dart';

/// AdMob ids and the Remove Ads product.
///
/// The native SDKs read the app id before Dart starts, so it also lives in
/// iOS `GADApplicationIdentifier` (Info.plist) and the Android
/// `APPLICATION_ID` (AndroidManifest). Keep them in sync with this file.
///
/// Ad *units* switch on build type: release builds use the live unit, and
/// debug and profile builds use Google's test unit, so playtesting never
/// taps a live ad (AdMob treats that as invalid traffic). A release build
/// with no live unit set loads no ads at all rather than test ads.
///
/// Source: https://developers.google.com/admob/flutter/interstitial
/// and https://developers.google.com/admob/flutter/quick-start
class AdConfig {
  const AdConfig._();

  /// Live iOS app id (Backyard Barrage, AdMob account 7671007992790429).
  static const String iosAppId = 'ca-app-pub-7671007992790429~3358046608';

  /// Sample Android app id. Android is not a store target yet.
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Live iOS interstitial unit (run end), used by release builds only.
  static const String iosInterstitialLiveId =
      'ca-app-pub-7671007992790429/2173544178';

  /// Google's sample iOS interstitial, used by debug and profile builds.
  static const String iosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  /// Google's sample Android interstitial.
  static const String androidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Waves won between interstitials when there is no boss or loss to
  /// show one after. Counts are for the app session. They are not saved.
  static const int interstitialWaves = 5;

  /// Fight time between any two interstitials, and before the first one
  /// after the app opens.
  static const Duration interstitialMinGap = Duration(minutes: 3);

  /// Non-consumable Remove Ads product. Its price is set in App Store
  /// Connect; the game shows the store's localized price.
  static const String removeAdsProductId =
      'dev.gamelogic.backyardbarrage.removeads';

  /// The unit to load, or empty for none. [release] defaults to
  /// [kReleaseMode]; tests pass it to check both builds.
  static String interstitialIdFor({bool release = kReleaseMode}) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidInterstitialId;
    }
    return release ? iosInterstitialLiveId : iosInterstitialId;
  }

  static String get interstitialId => interstitialIdFor();
}
