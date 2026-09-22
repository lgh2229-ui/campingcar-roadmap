from pathlib import Path

# TEMPORARY RELEASE-STABILITY MODE
# Do not add google_mobile_ads to Android builds. The current Google Mobile Ads
# integration has been isolated as a release-startup crash risk on Android.
# Keep the app functional first; ads can be restored after a release-device test.

# Defensive cleanup in case the dependency was committed by an earlier patch.
p = Path('pubspec.yaml')
s = p.read_text(encoding='utf-8')
lines = [line for line in s.splitlines() if not line.strip().startswith('google_mobile_ads:')]
p.write_text('\n'.join(lines) + '\n', encoding='utf-8')

# The repository source does not contain ad widgets/imports; this build patch
# intentionally performs no ad injection.
print('Mobile Ads disabled for release stability')
