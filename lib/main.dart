import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/end_ad_locator.dart';
import 'ads/remove_ads.dart';
import 'ads/remove_ads_locator.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fredokaLicense);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final removeAds = RemoveAdsController(catalog: createRemoveAdsCatalog());
  runApp(
    BackyardBarrageApp(endAd: createEndAd(removeAds), removeAds: removeAds),
  );
}

/// Bundled display font (SIL OFL 1.1). Shows up in the platform licence page.
Stream<LicenseEntry> _fredokaLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/fredoka/OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Fredoka'], text);
}
