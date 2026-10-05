import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/end_ad_locator.dart';
import 'ads/remove_ads.dart';
import 'ads/remove_ads_locator.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
