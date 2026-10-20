import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
static const appOpenUnitId = 'ca-app-pub-5092722454826299/7180384300';

static const _bannerHome = 'ca-app-pub-5092722454826299/6751727636';
static const _bannerTools = 'ca-app-pub-5092722454826299/8633241787';
static const _bannerLibrary = 'ca-app-pub-5092722454826299/5000399981';

static const _nativeHome = 'ca-app-pub-5092722454826299/3470958174';
static const _nativePdf1 = 'ca-app-pub-5092722454826299/2754229146';
static const _nativePdf2 = 'ca-app-pub-5092722454826299/9012340726';
static const _nativePdf3 = 'ca-app-pub-5092722454826299/1882544330';
static const _nativeImage = 'ca-app-pub-5092722454826299/8340141478';
static const _nativeEditSign = 'ca-app-pub-5092722454826299/3199124303';

static const _testInterstitialAndroid =
'ca-app-pub-5092722454826299/1699554425';
static const String _interstitialOverride =
String.fromEnvironment('ADMOB_INTERSTITIAL_UNIT_ID', defaultValue: '');

bool _initialized = false;
InterstitialAd? _interstitial;
AppOpenAd? _appOpenAd;
bool _appOpenRequested = false;
bool _appOpenShowing = false;
DateTime? _lastInterstitialShown;
int _actionsSinceLastInterstitial = 0;

static const _minGapBetweenInterstitials = Duration(minutes: 3);
static const _actionsRequiredBetweenInterstitials = 3;

bool get isReady => _initialized;

String get bannerUnitId => _bannerHome;

String bannerUnitIdFor(String placement) {
switch (placement) {
case 'tools':
return _bannerTools;
case 'library':
return _bannerLibrary;
default:
return _bannerHome;
}
}

String get interstitialUnitId =>
_interstitialOverride.isNotEmpty
? _interstitialOverride
: _testInterstitialAndroid;

String get nativeUnitId => _nativeEditSign;

String nativeUnitIdFor(String placement) {
switch (placement) {
case 'home':
return _nativeHome;
case 'pdf1':
return _nativePdf1;
case 'pdf2':
return _nativePdf2;
case 'pdf3':
return _nativePdf3;
case 'image':
return _nativeImage;
default:
return _nativeEditSign;
}
}

Future<void> init() async {
try {
await MobileAds.instance.initialize();
_initialized = true;
_preloadInterstitial();
_preloadAppOpen();
} catch (e) {
debugPrint('AdsService init failed; continuing without ads: $e');
_initialized = false;
}
}

void _preloadAppOpen() {
if (!_initialized || _appOpenAd != null) return;
AppOpenAd.load(
adUnitId: appOpenUnitId,
request: const AdRequest(),
adLoadCallback: AppOpenAdLoadCallback(
onAdLoaded: (ad) {
_appOpenAd = ad;
if (_appOpenRequested) _showAppOpen();
},
onAdFailedToLoad: (error) {
debugPrint('App Open load failed: ${error.message}');
_appOpenAd = null;
},
),
);
}

void requestAppOpenShow() {
if (!_initialized || _appOpenShowing) return;
_appOpenRequested = true;
if (_appOpenAd != null) _showAppOpen();
}

void _showAppOpen() {
final ad = _appOpenAd;
if (ad == null || _appOpenShowing) return;
_appOpenAd = null;
_appOpenRequested = false;
_appOpenShowing = true;
ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
onAdDismissedFullScreenContent: (ad) {
_appOpenShowing = false;
ad.dispose();
_preloadAppOpen();
},
onAdFailedToShowFullScreenContent: (ad, error) {
_appOpenShowing = false;
ad.dispose();
_preloadAppOpen();
},
);
ad.show();
}

void _preloadInterstitial() {
if (!_initialized) return;
InterstitialAd.load(
adUnitId: interstitialUnitId,
request: const AdRequest(),
adLoadCallback: InterstitialAdLoadCallback(
onAdLoaded: (ad) {
_interstitial = ad;
debugPrint('Interstitial loaded');
},
onAdFailedToLoad: (error) {
_interstitial = null;
debugPrint('Interstitial load failed: ${error.message}');
},
),
);
}

Future<void> maybeShowInterstitialAfterToolAction() async {
if (!_initialized || _interstitial == null) return;
_actionsSinceLastInterstitial++;
final now = DateTime.now();
final gapOk = _lastInterstitialShown == null ||
now.difference(_lastInterstitialShown!) > _minGapBetweenInterstitials;
if (!gapOk ||
_actionsSinceLastInterstitial < _actionsRequiredBetweenInterstitials) {
return;
}

final ad = _interstitial!;
_interstitial = null;
_actionsSinceLastInterstitial = 0;
_lastInterstitialShown = now;
ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
  onAdDismissedFullScreenContent: (ad) {
    ad.dispose();
    _preloadInterstitial();
  },
  onAdFailedToShowFullScreenContent: (ad, error) {
    ad.dispose();
    _preloadInterstitial();
  },
);
await ad.show();

}

void dispose() {
_interstitial?.dispose();
_appOpenAd?.dispose();
}
}
