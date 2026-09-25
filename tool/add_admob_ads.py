from pathlib import Path

# RELEASE STABILITY: keep Google Mobile Ads completely out of the Android
# binary until release startup has been proven stable on a physical device.
# This intentionally does not patch main.dart or HomeScreen.
pub = Path('pubspec.yaml')
s = pub.read_text(encoding='utf-8')
s = '\n'.join(
    line for line in s.splitlines()
    if not line.strip().startswith('google_mobile_ads:')
) + '\n'
pub.write_text(s, encoding='utf-8')
print('AdMob native plugin excluded for release stability test')
