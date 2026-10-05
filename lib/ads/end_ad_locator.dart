import 'end_ad.dart';
import 'remove_ads.dart';
import 'end_ad_web.dart' if (dart.library.io) 'end_ad_io.dart';

EndAd createEndAd(RemoveAdsController removeAds) =>
    createPlatformEndAd(removeAds);
