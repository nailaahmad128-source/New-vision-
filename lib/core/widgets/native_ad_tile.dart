import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ads_service.dart';

class NativeAdTile extends StatefulWidget {
  final bool wide;
  const NativeAdTile({super.key, this.wide = false});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad != null || _loaded) return;

    _ad = NativeAd(
      adUnitId: AdsService().nativeUnitId,
      factoryId: 'gridTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
          debugPrint('Native ad failed: ${error.message}');
        },
      ),
    )!..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.wide ? 16 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E3E7)),
      ),
      child: widget.wide
          ? const Row(
              children: [
                Icon(Icons.document_scanner_rounded,
                    color: Color(0xFF159B78), size: 42),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan smarter with ScanFlow',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Scan, convert and manage your documents easily.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF159B78)),
              ],
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF159B78), size: 27),
                SizedBox(height: 6),
                Text(
                  'ScanFlow',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ad != null && _loaded) {
      final adCard = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AdWidget(ad: _ad!),
      );
      return SizedBox(
        width: double.infinity,
        height: widget.wide ? 170 : 150,
        child: adCard,
      );
    }

    return widget.wide
        ? SizedBox(
            width: double.infinity,
            height: 150,
            child: _fallback(),
          )
        : SizedBox.expand(child: _fallback());
  }
}
