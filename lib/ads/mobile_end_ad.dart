import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'end_ad.dart';
import 'remove_ads.dart';

/// UMP consent, the iOS tracking prompt, then an interstitial when allowed.
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
          await _requestTracking();
          await _startAdsIfAllowed();
        });
      },
      (_) async {
        await _requestTracking();
        await _startAdsIfAllowed();
      },
    );
  }

  Future<void> _requestTracking() async {
    if (removeAds.owned) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (removeAds.owned || status != TrackingStatus.notDetermined) return;
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {
      // The prompt is iOS-only. A missing plugin must not block the game.
    }
  }

  Future<void> _startAdsIfAllowed() async {
    if (removeAds.owned) return;
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _load();
    } catch (_) {}
  }

  void _load() {
    if (removeAds.owned || _loading || _ready != null) return;
    // A release build without a live unit shows no ads, never test ads.
    if (AdConfig.interstitialId.isEmpty) return;
    _loading = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: AdConfig.interstitialId,
        request: const AdRequest(),
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
