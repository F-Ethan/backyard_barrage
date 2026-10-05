import 'end_ad.dart';
import 'remove_ads.dart';

/// Web builds do not load the ads or store plugins.
EndAd createPlatformEndAd(RemoveAdsController removeAds) => const NoEndAd();
