import 'dart:io';

import 'package:backyard_barrage/ads/ad_config.dart';
import 'package:backyard_barrage/ads/ad_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ads follow bosses and losses, else every five minutes', () {
    expect(AdConfig.interstitialEvery, const Duration(minutes: 5));
    expect(AdConfig.interstitialMinGap, const Duration(minutes: 1));
    bool allows(AdMoment moment, int seconds, {bool fight = false}) =>
        AdPolicy.allows(
          inFight: fight,
          moment: moment,
          playSinceAd: Duration(seconds: seconds),
          anyShown: true,
        );
    // Boss and loss: after a minute of fighting since the last ad.
    for (final moment in [AdMoment.bossBeaten, AdMoment.defeat]) {
      expect(allows(moment, 59), isFalse);
      expect(allows(moment, 60), isTrue);
      expect(
        AdPolicy.allows(
          inFight: false,
          moment: moment,
          playSinceAd: Duration.zero,
          anyShown: false,
        ),
        isTrue,
        reason: 'the first one of the session shows',
      );
    }
    // Any other break: five minutes.
    expect(allows(AdMoment.breakTime, 299), isFalse);
    expect(allows(AdMoment.breakTime, 300), isTrue);
    // Never in a fight.
    for (final moment in AdMoment.values) {
      expect(allows(moment, 3600, fight: true), isFalse);
    }
  });

  test('native app ids match the single Dart config', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(plist, contains('<string>${AdConfig.iosAppId}</string>'));
    expect(manifest, contains(AdConfig.androidAppId));
    expect(AdConfig.iosAppId, startsWith('ca-app-pub-7671007992790429~'));
    // Debug and profile builds stay on Google's test unit; release uses the
    // live unit.
    expect(AdConfig.iosInterstitialId, contains('4411468910'));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(
        AdConfig.interstitialIdFor(release: false),
        AdConfig.iosInterstitialId,
      );
      expect(
        AdConfig.interstitialIdFor(release: true),
        AdConfig.iosInterstitialLiveId,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(
      AdConfig.iosInterstitialLiveId,
      'ca-app-pub-7671007992790429/2173544178',
    );
    expect(AdConfig.androidInterstitialId, contains('1033173712'));
    expect(
      AdConfig.removeAdsProductId,
      'dev.gamelogic.backyardbarrage.removeads',
    );
    // Kid-safe: no tracking prompt, and the privacy manifest declares no
    // tracking.
    expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(privacy, isNot(contains('<true/>')));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('app_tracking_transparency')),
    );
    final encryption = plist.indexOf(
      '<key>ITSAppUsesNonExemptEncryption</key>',
    );
    expect(encryption, greaterThan(0));
    expect(plist.substring(encryption, encryption + 60), contains('<false/>'));
  });

  test('iPad stays landscape and opts out of multitasking', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('Portrait')));
    expect(plist, contains('<key>UISupportedInterfaceOrientations</key>'));
    expect(plist, contains('<key>UISupportedInterfaceOrientations~ipad</key>'));
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(plist, contains('UIInterfaceOrientationLandscapeRight'));
    final fullscreen = plist.indexOf('<key>UIRequiresFullScreen</key>');
    expect(fullscreen, greaterThan(0));
    expect(plist.substring(fullscreen, fullscreen + 48), contains('<true/>'));
  });

  test('the iOS build allows the ads plugin private header include', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    const flag = 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES';
    expect(podfile, contains("$flag'] = 'YES'"));
    expect(flag.allMatches(project), hasLength(6));
  });
}
