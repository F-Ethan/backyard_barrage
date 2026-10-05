import 'end_ad.dart';
import 'remove_ads.dart';

EndAd createPlatformEndAd(RemoveAdsController removeAds) {
  // Web does not load the ads or store plugins.
  return removeAds.owned ? const NoEndAd() : const NoEndAd();
}
