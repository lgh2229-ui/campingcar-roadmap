from pathlib import Path

# Temporary production-safe fallback: disable AdMob until the native release crash is resolved.
# This restores the last empirically verified configuration that launches on the device.
pub = Path('pubspec.yaml')
s = pub.read_text(encoding='utf-8')
s = '\n'.join(line for line in s.splitlines() if 'google_mobile_ads:' not in line) + '\n'
pub.write_text(s, encoding='utf-8')

ad = Path('lib/widgets/admob_banner.dart')
if ad.exists():
    ad.unlink()

# No source rewriting is needed when AdMob is disabled.
print('AdMob disabled: restored release-launch baseline')
