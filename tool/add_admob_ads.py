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

# Put a safe banner above the bottom navigation on every main tab.
old = '''      bottomNavigationBar: NavigationBar(\n        selectedIndex: tab,'''
new = '''      bottomNavigationBar: Column(\n        mainAxisSize: MainAxisSize.min,\n        children: [\n          const _AdMobBanner(),\n          NavigationBar(\n        selectedIndex: tab,'''
if old in s and 'const _AdMobBanner(),' not in s:
    s = s.replace(old, new, 1)
    anchor = '''        ],\n      ),\n    );\n  }\n\n  Widget _mapPage()'''
    replacement = '''        ],\n          ),\n        ],\n      ),\n    );\n  }\n\n  Widget _mapPage()'''
    if anchor not in s:
        raise SystemExit('bottom navigation close anchor not found')
    s = s.replace(anchor, replacement, 1)

# Insert a small native ad after every 7 saved places.
old_saved = '''        Expanded(child: rows.isEmpty ? const Center(child: Text('저장한 장소가 없습니다.')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {\n          final p = rows[i];'''
new_saved = '''        Expanded(child: rows.isEmpty ? const Center(child: Text('저장한 장소가 없습니다.')) : ListView.builder(\n          itemCount: rows.length + (rows.length ~/ 7),\n          itemBuilder: (_, i) {\n          if ((i + 1) % 8 == 0) return const _NativeAdCard();\n          final placeIndex = i - (i ~/ 8);\n          final p = rows[placeIndex];'''
if old_saved in s:
    s = s.replace(old_saved, new_saved, 1)
elif 'return const _NativeAdCard();' not in s:
    raise SystemExit('saved list anchor not found')

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
'''

if 'class _NativeAdCard extends StatefulWidget' not in s:
    s += r'''

class _NativeAdCard extends StatefulWidget {
  const _NativeAdCard();
  @override
  State<_NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<_NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = NativeAd(
      adUnitId: AdMobIds.testNative,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        cornerRadius: 10,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 90, maxHeight: 130),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
'''

if 'class AdMobIds' not in s:
    s += r'''

class AdMobIds {
  static const appId = 'ca-app-pub-4393751265116181~3875944017';
  static const banner = 'ca-app-pub-4393751265116181/5011107880';
  static const native = 'ca-app-pub-4393751265116181/5268565087';
  static const testNative = 'ca-app-pub-3940256099942544/2247696110';
}
'''
p.write_text(s, encoding='utf-8')
