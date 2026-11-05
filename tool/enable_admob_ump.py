from pathlib import Path

def replace_once(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if s.count(old) != 1:
        raise SystemExit('UMP patch anchor missing/non-unique: ' + path + ' / ' + old[:50])
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

Path('lib/services/ad_consent_service.dart').write_text("""
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Request Google UMP consent once on each launch before loading ads.
class RoadmapAdConsent extends ChangeNotifier {
  RoadmapAdConsent._();
  static final RoadmapAdConsent instance = RoadmapAdConsent._();
  Future<bool>? _pending;
  bool _privacyOptionsRequired = false;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<bool> initialize() => _pending ??= _gather();

  Future<bool> _gather() async {
    final result = Completer<bool>();
    Future<void> finish() async {
      try {
        final status = await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus();
        final required = status == PrivacyOptionsRequirementStatus.required;
        if (_privacyOptionsRequired != required) {
          _privacyOptionsRequired = required;
          notifyListeners();
        }
        final allowed = await ConsentInformation.instance.canRequestAds();
        if (!result.isCompleted) result.complete(allowed);
      } catch (error) {
        debugPrint('UMP status unavailable: ' + error.toString());
        if (!result.isCompleted) result.complete(false);
      }
    }
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
              if (error != null) {
                debugPrint('UMP form error: ' + error.message);
              }
              unawaited(finish());
            });
          } catch (error) {
            debugPrint('UMP form startup: ' + error.toString());
            unawaited(finish());
          }
        },
        (FormError error) {
          debugPrint('UMP update error: ' + error.message);
          // Reuse a previous valid UMP consent status if available.
          unawaited(finish());
        },
      );
    } catch (error) {
      debugPrint('UMP SDK error: ' + error.toString());
      unawaited(finish());
    }
    // Fail closed if UMP hangs, without preventing use of the app.
    return result.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
  }

  Future<void> showPrivacyOptions() async {
    await initialize();
    if (!_privacyOptionsRequired) return;
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) debugPrint('UMP privacy settings: ' + error.message);
      });
    } catch (error) {
      debugPrint('UMP settings unavailable: ' + error.toString());
    }
  }
}
""".lstrip(), encoding='utf-8')

Path('lib/widgets/ad_privacy_options_button.dart').write_text("""
import 'package:flutter/material.dart';
import '../services/ad_consent_service.dart';

class AdPrivacyOptionsButton extends StatelessWidget {
  const AdPrivacyOptionsButton({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RoadmapAdConsent.instance,
    builder: (context, child) {
      if (!RoadmapAdConsent.instance.privacyOptionsRequired) {
        return const SizedBox.shrink();
      }
      return TextButton.icon(
        icon: const Icon(Icons.privacy_tip_outlined),
        label: const Text('광고 개인정보 설정'),
        onPressed: () { RoadmapAdConsent.instance.showPrivacyOptions(); },
      );
    },
  );
}
""".lstrip(), encoding='utf-8')

# The original banner generator is intentionally replaced after it runs.
Path('lib/widgets/admob_banner.dart').write_text("""
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_consent_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) { _loadIfPermitted(); });
  }

  Future<void> _loadIfPermitted() async {
    try {
      // IMPORTANT: do not initialize or request AdMob ads before UMP approval.
      final allowed = await RoadmapAdConsent.instance.initialize();
      if (!mounted || !allowed) return;
      await MobileAds.instance.initialize();
      if (!mounted) return;
      final ad = BannerAd(
        adUnitId: 'ca-app-pub-4393751265116181/4592255152',
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('AdMob error: ' + error.toString());
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (error) {
      debugPrint('AdMob unavailable: ' + error.toString());
    }
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      height: ad.size.height.toDouble(),
      child: Center(child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      )),
    );
  }
}
""".lstrip(), encoding='utf-8')

replace_once(
  'lib/main.dart',
  "import 'config/app_config.dart';",
  "import 'config/app_config.dart';\nimport 'services/ad_consent_service.dart';"
)
replace_once(
  'lib/main.dart',
  '    _startup();',
  '    _startup();\n'
  '    WidgetsBinding.instance.addPostFrameCallback((_) {\n'
  '      RoadmapAdConsent.instance.initialize();\n'
  '    });'
)
replace_once(
  'lib/screens/login_screen.dart',
  "import '../repositories/auth_repository.dart';",
  "import '../repositories/auth_repository.dart';\nimport '../widgets/ad_privacy_options_button.dart';"
)
replace_once(
  'lib/screens/login_screen.dart',
  "                OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text('회원가입')),",
  "                OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text('회원가입')),\n"
  "                const SizedBox(height: 8),\n"
  "                const AdPrivacyOptionsButton(),"
)
replace_once(
  'lib/screens/home_screen.dart',
  "import '../widgets/place_detail_sheet.dart';",
  "import '../widgets/place_detail_sheet.dart';\nimport '../widgets/ad_privacy_options_button.dart';"
)
home = Path('lib/screens/home_screen.dart')
s = home.read_text(encoding='utf-8')
start = s.find('Widget _profilePage()')
end = s.find('Future<void> _openMyResponses()', start)
if start < 0 or end < 0:
    raise SystemExit('UMP profile location not found')
fragment = s[start:end]
old = '          TextButton.icon(onPressed: _deleteAccount,'
if fragment.count(old) != 1:
    raise SystemExit('UMP profile action not found')
fragment = fragment.replace(
  old, '          const AdPrivacyOptionsButton(),\n'
       '          const SizedBox(height: 8),\n' + old, 1)
home.write_text(s[:start] + fragment + s[end:], encoding='utf-8')
print('UMP: launch consent, no ads without permission, privacy options on login and profile')
