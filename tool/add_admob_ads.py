from pathlib import Path

# RELEASE STABILITY: AdMob native plugin is disabled.
# Physical-device release testing proved that adding google_mobile_ads makes
# the release app terminate at startup. Keep the known-good release path until
# the native crash is diagnosed separately.
pub = Path('pubspec.yaml')
s = pub.read_text(encoding='utf-8')
s = '\n'.join(line for line in s.splitlines() if not line.strip().startswith('google_mobile_ads:')) + '\n'
pub.write_text(s, encoding='utf-8')
print('AdMob disabled: preserving known-good release startup')
