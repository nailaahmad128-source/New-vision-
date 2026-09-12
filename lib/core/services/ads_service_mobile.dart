import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralizes all AdMob logic: SDK init, ad unit IDs, and interstitial
/// frequency capping so ads never appear back-to-back or interrupt an
/// in-progress tool action.
///
/// Ad unit IDs are read from --dart-define at build time (see the CI
/// workflow / README) and fall back to Google's public test IDs so debug
/// builds never accidentally serve — or need — real ads. NOTHING here
/// hard-codes a real AdMob app ID or ad unit ID.
class AdsService {
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';

  static const String _bannerIdOverride =
      String.fromEnvironment('ADMOB_BANNER_UNIT_ID', defaultValue: '');
  static const String _interstitialIdOverride =
      String.fromEnvironment('ADMOB_INTERSTITIAL_UNIT_ID', defaultValue: '');

  bool _initialized = false;
  InterstitialAd? _interstitial;
  DateTime? _lastInterstitialShown;
  int _actionsSinceLastInterstitial = 0;

  /// Minimum real-world gap between interstitials, regardless of how many
  /// tool actions happen in between — this is the core of "non-intrusive".
  static const _minGapBetweenInterstitials = Duration(minutes: 3);

  /// Number of completed tool actions required before another interstitial
  /// is even considered.
  static const _actionsRequiredBetweenInterstitials = 3;

  String get bannerUnitId {
    if (!Platform.isAndroid) return _testBannerAndroid;
    return _bannerIdOverride.isNotEmpty ? _bannerIdOverride : _testBannerAndroid;
  }

  String get interstitialUnitId {
    if (!Platform.isAndroid) return _testInterstitialAndroid;
    return _interstitialIdOverride.isNotEmpty
        ? _interstitialIdOverride
        : _testInterstitialAndroid;
  }

  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _preloadInterstitial();
    } catch (e) {
      debugPrint('AdsService: init failed, continuing ad-free: $e');
      _initialized = false;
    }
  }

  bool get isReady => _initialized;

  void _preloadInterstitial() {
    if (!_initialized) return;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call after a tool successfully completes a job. Internally decides —
  /// based on cadence, not every single call — whether it's an appropriate
  /// moment to show a preloaded interstitial. Never shows one while the
  /// user is actively mid-flow (e.g. inside the signature canvas); only
  /// call this from a "result ready" screen.
  Future<void> maybeShowInterstitialAfterToolAction() async {
    if (!_initialized || _interstitial == null) return;
    _actionsSinceLastInterstitial++;
    final now = DateTime.now();
    final gapOk = _lastInterstitialShown == null ||
        now.difference(_lastInterstitialShown!) > _minGapBetweenInterstitials;
    final countOk = _actionsSinceLastInterstitial >= _actionsRequiredBetweenInterstitials;
    if (!gapOk || !countOk) return;

    final ad = _interstitial!;
    _interstitial = null;
    _actionsSinceLastInterstitial = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _preloadInterstitial();
      },
    );
    _lastInterstitialShown = now;
    await ad.show();
  }

  void dispose() {
    _interstitial?.dispose();
  }
}
