import 'end_ad.dart';
import 'mobile_end_ad.dart';
import 'remove_ads.dart';

EndAd createPlatformEndAd(RemoveAdsController removeAds) =>
    MobileEndAd(removeAds);
