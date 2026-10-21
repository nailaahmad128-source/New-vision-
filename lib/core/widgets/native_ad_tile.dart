import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ads_service.dart';

class NativeAdTile extends StatefulWidget {
final bool wide;
final String placement;
final ValueChanged<bool>? onVisibilityChanged;

const NativeAdTile({
super.key,
this.wide = false,
this.placement = 'home',
this.onVisibilityChanged,
});

@override
State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
NativeAd? _ad;
bool _loaded = false;

@override
void didChangeDependencies() {
super.didChangeDependencies();
if (_ad != null) return;

_ad = NativeAd(
  adUnitId: AdsService().nativeUnitIdFor(widget.placement),
  factoryId: 'gridTile',
  request: const AdRequest(),
  listener: NativeAdListener(
    onAdLoaded: (ad) {
      if (mounted) {
        setState(() => _loaded = true);
        widget.onVisibilityChanged?.call(true);
      }
    },
    onAdFailedToLoad: (ad, error) {
      ad.dispose();
      if (mounted) {
        setState(() {
          _ad = null;
          _loaded = false;
        });
        widget.onVisibilityChanged?.call(false);
      }
      debugPrint('Native ad ${widget.placement} failed: ${error.message}');
    },
  ),
)!..load();

}

@override
void dispose() {
_ad?.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
if (!_loaded || _ad == null) return const SizedBox.shrink();
return SizedBox(
width: double.infinity,
height: double.infinity,
child: ClipRRect(
borderRadius: BorderRadius.circular(20),
child: Container(color: Colors.white, child: AdWidget(ad: _ad!)),
),
);
}
}
