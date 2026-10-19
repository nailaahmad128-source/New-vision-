import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) {
      final ads = AdsService();
      _ad = NativeAd(
        adUnitId: ads.nativeUnitId,
        factoryId: 'gridTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) setState(() {
              _ad = null;
              _loaded = false;
            });
            debugPrint('Native ad failed: ${error.message}');
          },
        ),
      )!..load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E3E7)),
        ),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
