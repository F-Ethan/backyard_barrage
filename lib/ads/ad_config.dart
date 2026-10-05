import 'package:flutter/foundation.dart';

/// Google's official sample IDs. Swap these, the iOS
/// `GADApplicationIdentifier`, and the Android `APPLICATION_ID` together
/// before a store build. The native SDKs read the app ID before Dart starts,
/// so it cannot live only in this file. Unit IDs are read from here.
///
/// Source: https://developers.google.com/admob/flutter/interstitial
/// and https://developers.google.com/admob/flutter/quick-start
class AdConfig {
  const AdConfig._();

  /// Sample iOS app ID.
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// Sample Android app ID.
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Sample iOS interstitial.
  static const String iosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  /// Sample Android interstitial.
  static const String androidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  /// A run must last longer than this, in fight time, before an end ad.
  static const double minFightSeconds = 120;

  static String get interstitialId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidInterstitialId;
    }
    return iosInterstitialId;
  }
}
