class AdsService {
bool get isReady => false;
String get bannerUnitId => '';
String bannerUnitIdFor(String placement) => '';
String get interstitialUnitId => '';
String get nativeUnitId => '';
String nativeUnitIdFor(String placement) => '';
Future<void> init() async {}
void requestAppOpenShow() {}
Future<void> maybeShowInterstitialAfterToolAction() async {}
void dispose() {}
}
