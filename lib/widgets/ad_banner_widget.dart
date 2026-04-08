import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reusable inline banner ad widget.
///
/// Uses Google's official test ad-unit IDs by default.
/// Replace [_androidAdUnitId] and [_iosAdUnitId] with your real AdMob
/// ad-unit IDs before publishing.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  // ── Replace these with your real ad-unit IDs before publishing ──────────
  static const _androidAdUnitId = 'ca-app-pub-1046301270032418/5019674414';
  static const _iosAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  // ────────────────────────────────────────────────────────────────────────

  BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;
    final banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner, // 320×50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          dev.log('AdMob failed to load: ${error.code} – ${error.message}',
              name: 'AdBannerWidget');
          ad.dispose();
        },
      ),
    );
    banner.load();
    _bannerAd = banner;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _bannerAd == null) {
      // Invisible placeholder while ad loads — keeps list layout stable
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
