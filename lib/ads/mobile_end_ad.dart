import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'end_ad.dart';

/// UMP consent, the iOS tracking prompt, then one interstitial per ending.
class MobileEndAd extends EndAd {
  InterstitialAd? _ready;
  var _loading = false;
  var _prepared = false;
  var _showing = false;

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {
      // The prompt is iOS-only. A missing plugin must not block the game.
    }
  }

  Future<void> _startAdsIfAllowed() async {
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _load();
    } catch (_) {}
  }

  void _load() {
    if (_loading || _ready != null) return;
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
  Future<void> onRunEnded({required double fightSeconds}) async {
    if (_showing) return;
    final ad = _ready;
    _ready = null;
    if (ad == null) {
      _load();
      return;
    }
    _showing = true;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _load();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showing = false;
        _load();
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      _showing = false;
      ad.dispose();
      _load();
      return;
    }
    await done.future;
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
}
