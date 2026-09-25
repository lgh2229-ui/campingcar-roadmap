from pathlib import Path

# Restore AdMob safely at build time. The repository keeps the dependency,
# and this patch injects a reusable banner widget plus MobileAds initialization.
pub = Path('pubspec.yaml')
s = pub.read_text(encoding='utf-8')
if 'google_mobile_ads:' not in s:
    s = s.replace('  url_launcher: ^6.3.2\n', '  url_launcher: ^6.3.2\n  google_mobile_ads: ^7.0.0\n')
    pub.write_text(s, encoding='utf-8')

ad = Path('lib/widgets/admob_banner.dart')
ad.parent.mkdir(parents=True, exist_ok=True)
ad.write_text("""import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    const productionAdUnitId = String.fromEnvironment('ADMOB_BANNER_UNIT_ID');
    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111'
        : productionAdUnitId;
    // Never create a release BannerAd with a placeholder/invalid unit ID.
    // An invalid release ID can terminate the app on startup on some devices.
    if (adUnitId.isEmpty) return;
    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
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
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
""", encoding='utf-8')

main = Path('lib/main.dart')
m = main.read_text(encoding='utf-8')
if "package:google_mobile_ads/google_mobile_ads.dart" not in m:
    m = m.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:google_mobile_ads/google_mobile_ads.dart';")
if 'MobileAds.instance.initialize();' not in m:
    m = m.replace('  WidgetsFlutterBinding.ensureInitialized();', '  WidgetsFlutterBinding.ensureInitialized();\n  // Do not block first frame on ads startup.\n  MobileAds.instance.initialize();')
main.write_text(m, encoding='utf-8')

home = Path('lib/screens/home_screen.dart')
h = home.read_text(encoding='utf-8')
if "../widgets/admob_banner.dart" not in h:
    h = h.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport '../widgets/admob_banner.dart';")
old = """      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: '저장'),
          NavigationDestination(icon: Icon(Icons.add_location_alt_outlined), selectedIcon: Icon(Icons.add_location_alt), label: '내등록'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),
        ],
      ),"""
new = """      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdMobBanner(),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
              NavigationDestination(icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: '저장'),
              NavigationDestination(icon: Icon(Icons.add_location_alt_outlined), selectedIcon: Icon(Icons.add_location_alt), label: '내등록'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),
            ],
          ),
        ],
      ),"""
if old in h:
    h = h.replace(old, new, 1)
elif 'const AdMobBanner()' not in h:
    marker = '      bottomNavigationBar:'
    pos = h.find(marker)
    if pos < 0:
        raise SystemExit('HomeScreen bottomNavigationBar not found')
    # Other build patches may have reformatted NavigationBar. Inject the banner
    # using a stable wrapper around the existing bottomNavigationBar expression.
    start = pos + len(marker)
    nav = h.find('NavigationBar(', start)
    if nav < 0:
        raise SystemExit('HomeScreen NavigationBar not found')
    h = h[:start] + ' Column(mainAxisSize: MainAxisSize.min, children: [const AdMobBanner(), ' + h[start:]
    # Close the wrapper immediately after the NavigationBar block, before Scaffold close.
    close = h.find('\n      ),\n    );', nav)
    if close < 0:
        raise SystemExit('HomeScreen NavigationBar closing marker not found')
    h = h[:close + len('\n      ),')] + ']),' + h[close + len('\n      ),'):]

home.write_text(h, encoding='utf-8')

print('AdMob banner restored with Google test banner for debug builds')
