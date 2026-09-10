from pathlib import Path

# pubspec
p = Path('pubspec.yaml')
s = p.read_text(encoding='utf-8')
if 'google_mobile_ads:' not in s:
    s = s.replace('  uuid: ^4.5.1\n', '  uuid: ^4.5.1\n  google_mobile_ads: ^9.1.0\n')
else:
    import re
    s = re.sub(r'  google_mobile_ads: .*\n', '  google_mobile_ads: ^9.1.0\n', s)
p.write_text(s, encoding='utf-8')

# main: initialize Mobile Ads SDK
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
if "package:google_mobile_ads/google_mobile_ads.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:google_mobile_ads/google_mobile_ads.dart';")
if 'MobileAds.instance.initialize()' not in s:
    s = s.replace('  WidgetsFlutterBinding.ensureInitialized();', '  WidgetsFlutterBinding.ensureInitialized();\n  await MobileAds.instance.initialize();')
p.write_text(s, encoding='utf-8')

# Home screen: development APK uses Google's dedicated Android test IDs.
p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
if "package:google_mobile_ads/google_mobile_ads.dart" not in s:
    s = s.replace("import 'package:geolocator/geolocator.dart';", "import 'package:geolocator/geolocator.dart';\nimport 'package:google_mobile_ads/google_mobile_ads.dart';")

# Put a safe banner above the bottom navigation on every main tab. This includes map and saved list.
old = '''      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,'''
new = '''      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AdMobBanner(),
          NavigationBar(
        selectedIndex: tab,'''
if old in s and 'const _AdMobBanner(),' not in s:
    s = s.replace(old, new, 1)
    anchor = '''        ],
      ),
    );
  }

  Widget _mapPage()'''
    replacement = '''        ],
          ),
        ],
      ),
    );
  }

  Widget _mapPage()'''
    if anchor not in s:
        raise SystemExit('bottom navigation close anchor not found')
    s = s.replace(anchor, replacement, 1)

if 'class _AdMobBanner extends StatefulWidget' not in s:
    s += r'''

class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner();
  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, error) { ad.dispose(); },
      ),
    );
    _ad = ad;
    ad.load();
  }
  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(top: false, bottom: false, child: SizedBox(
      width: _ad!.size.width.toDouble(), height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    ));
  }
}

class AdMobIds {
  static const appId = 'ca-app-pub-4393751265116181~3875944017';
  static const banner = 'ca-app-pub-4393751265116181/5011107880';
  static const native = 'ca-app-pub-4393751265116181/5268565087';
  static const testNative = 'ca-app-pub-3940256099942544/2247696110';
}
'''
p.write_text(s, encoding='utf-8')
