import 'dart:io';

import 'package:backyard_barrage/ads/ad_config.dart';
import 'package:backyard_barrage/ads/ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an end ad needs a finished fight longer than two minutes', () {
    expect(
      AdPolicy.allows(fightSeconds: 120, alreadyShown: false, inFight: false),
      isFalse,
    );
    expect(
      AdPolicy.allows(
        fightSeconds: 120.01,
        alreadyShown: false,
        inFight: false,
      ),
      isTrue,
    );
    expect(
      AdPolicy.allows(fightSeconds: 400, alreadyShown: false, inFight: true),
      isFalse,
    );
    expect(
      AdPolicy.allows(fightSeconds: 400, alreadyShown: true, inFight: false),
      isFalse,
    );
  });

  test('native app ids match the single Dart config', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(plist, contains('<string>${AdConfig.iosAppId}</string>'));
    expect(manifest, contains(AdConfig.androidAppId));
    expect(AdConfig.iosInterstitialId, contains('4411468910'));
    expect(AdConfig.androidInterstitialId, contains('1033173712'));
    expect(
      AdConfig.removeAdsProductId,
      'dev.gamelogic.backyardbarrage.removeads',
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
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    const flag = 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES';
    expect(podfile, contains("$flag'] = 'YES'"));
    expect(flag.allMatches(project), hasLength(6));
  });
}
