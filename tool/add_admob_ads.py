from pathlib import Path

# AdMob production banner build: validated plugin/toolchain + production banner ID.
# This separates an account/app-ID configuration problem from a plugin problem.
pub = Path('pubspec.yaml')
s = pub.read_text(encoding='utf-8')
if 'google_mobile_ads:' not in s:
    s = s.replace('  url_launcher: ^6.3.2\n', '  url_launcher: ^6.3.2\n  google_mobile_ads: ^9.1.0\n')
pub.write_text(s, encoding='utf-8')

ad = Path('lib/widgets/admob_banner.dart')
ad.parent.mkdir(parents=True, exist_ok=True)
ad.write_text("""import 'package:flutter/material.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await MobileAds.instance.initialize();
        if (!mounted) return;
        final ad = BannerAd(
          adUnitId: 'ca-app-pub-4393751265116181/4592255152',
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
            onAdFailedToLoad: (ad, error) { ad.dispose(); debugPrint('AdMob: $error'); },
          ),
        );
        _ad = ad;
        await ad.load();
      } catch (e, st) {
        debugPrint('AdMob init failed: $e');
        debugPrintStack(stackTrace: st);
      }
    });
  }
  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(height: ad.size.height.toDouble(), child: Center(child: SizedBox(
      width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad))));
  }
}
""", encoding='utf-8')

home = Path('lib/screens/home_screen.dart')
h = home.read_text(encoding='utf-8')
if "../widgets/admob_banner.dart" not in h:
    h = h.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport '../widgets/admob_banner.dart';")
if 'const AdMobBanner()' not in h:
    marker='      bottomNavigationBar:'
    start=h.find(marker)
    nav=h.find('NavigationBar(', start)
    if start < 0 or nav < 0: raise SystemExit('bottom navigation marker not found')
    insert=start+len(marker)
    h=h[:insert]+' Column(mainAxisSize: MainAxisSize.min, children: [const AdMobBanner(), '+h[insert:]
    close=h.find('\n      ),\n    );', nav)
    if close < 0: raise SystemExit('navigation closing marker not found')
    h=h[:close+len('\n      ),')]+']),'+h[close+len('\n      ),'):]
home.write_text(h, encoding='utf-8')
print('AdMob production banner configured')
