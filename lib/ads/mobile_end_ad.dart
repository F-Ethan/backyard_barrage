import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'end_ad.dart';
import 'remove_ads.dart';

/// Ad settings for a game aimed at kids (a 4+ family game, general
/// audience): child age treatment (no personalisation or tracking) and only
/// G-rated ads.
RequestConfiguration get kidSafeRequestConfiguration => RequestConfiguration(
  ageRestrictedTreatment: AgeRestrictedTreatment.child,
  maxAdContentRating: MaxAdContentRating.g,
);

/// Every interstitial request: non-personalised.
const AdRequest kidSafeRequest = AdRequest(nonPersonalizedAds: true);

/// UMP consent, then a kid-safe interstitial when allowed.
///
/// The game is treated as directed to children (a 4+ family game), so it
/// never shows the iOS tracking prompt, and every ad request is tagged
/// child-directed and under the age of consent, rated G, and
/// non-personalised. Consent is checked again before every load.
class MobileEndAd extends EndAd {
  MobileEndAd(this.removeAds);

  final RemoveAdsController removeAds;
  InterstitialAd? _ready;
  var _loading = false;
  var _prepared = false;
  var _showing = false;

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
    await removeAds.prepare();
    if (removeAds.owned) return;
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) async {
          await _startAdsIfAllowed();
        });
      },
      (_) async {
        await _startAdsIfAllowed();
      },
    );
  }

  var _started = false;

  Future<void> _startAdsIfAllowed() async {
    if (removeAds.owned) return;
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.updateRequestConfiguration(
        kidSafeRequestConfiguration,
      );
      await MobileAds.instance.initialize();
      _started = true;
      _load();
    } catch (_) {}
  }

  /// Loads the next interstitial, only after the SDK started with the
  /// kid-safe settings and only while consent still allows ads.
  void _load() {
    if (removeAds.owned || _loading || _ready != null || !_started) return;
    // A release build without a live unit shows no ads, never test ads.
    if (AdConfig.interstitialId.isEmpty) return;
    _loading = true;
    unawaited(_loadIfAllowed());
  }

  Future<void> _loadIfAllowed() async {
    try {
      if (!await ConsentInformation.instance.canRequestAds()) {
        _loading = false;
        return;
      }
    } catch (_) {
      _loading = false;
      return;
    }
    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: kidSafeRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ready = ad;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          _ready = null;
        },
      ),
    );
  }

  @override
  Future<bool> onRunEnded({required double fightSeconds}) async {
    if (removeAds.owned) {
      _ready?.dispose();
      _ready = null;
      return false;
    }
    if (_showing) return false;
    final ad = _ready;
    _ready = null;
    if (ad == null) {
      _load();
      return false;
    }
    _showing = true;
    final done = Completer<bool>();
    var presented = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        presented = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _load();
        if (!done.isCompleted) done.complete(presented);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showing = false;
        _load();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show();
    } catch (_) {
      _showing = false;
      ad.dispose();
      _load();
      return false;
    }
    return done.future;
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
}
