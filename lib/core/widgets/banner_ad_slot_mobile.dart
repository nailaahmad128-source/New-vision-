import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/ads_service.dart';

class BannerAdSlot extends StatefulWidget {
final String placement;
const BannerAdSlot({super.key, this.placement = 'home'});

@override
State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
BannerAd? _ad;
bool _loaded = false;

@override
void didChangeDependencies() {
super.didChangeDependencies();
if (_ad == null) _load();
}

void _load() {
final ads = context.read<AdsService>();
if (!ads.isReady) return;

final banner = BannerAd(
  adUnitId: ads.bannerUnitIdFor(widget.placement),
  size: AdSize.banner,
  request: const AdRequest(),
  listener: BannerAdListener(
    onAdLoaded: (ad) {
      if (mounted) setState(() => _loaded = true);
    },
    onAdFailedToLoad: (ad, error) {
      ad.dispose();
      if (mounted) setState(() => _loaded = false);
      debugPrint('Banner ${widget.placement} failed: ${error.message}');
    },
  ),
);
_ad = banner;
banner.load();

}

@override
void dispose() {
_ad?.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
if (!_loaded || _ad == null) return const SizedBox.shrink();
return Container(
alignment: Alignment.center,
width: _ad!.size.width.toDouble(),
height: _ad!.size.height.toDouble(),
margin: const EdgeInsets.symmetric(vertical: 4),
child: AdWidget(ad: _ad!),
);
}
}
