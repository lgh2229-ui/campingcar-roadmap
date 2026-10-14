"""Fail the Google Play release if the packaged Android manifest requests
broad photo/video media library permissions, including permissions introduced
by Flutter plugins during the Android manifest merge.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

FORBIDDEN = {
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
}
ANDROID_NAME = '{http://schemas.android.com/apk/res/android}name'
root = Path('build/app/intermediates')
manifests = [
    f for f in root.rglob('AndroidManifest.xml')
    if 'release' in str(f).lower()
    and ('merged_manifest' in str(f).lower()
         or 'packaged_manifest' in str(f).lower())
]
if not manifests:
    raise SystemExit('ERROR: No merged/packaged release AndroidManifest.xml found; cannot verify Play release')
for manifest in manifests:
    doc = ET.parse(manifest)
    found = {
        el.attrib.get(ANDROID_NAME, '')
        for el in doc.getroot().iter()
        if el.tag in ('uses-permission', 'uses-permission-sdk-23', 'uses-permission-sdk-m')
    }
    bad = found.intersection(FORBIDDEN)
    if bad:
        raise SystemExit(f'ERROR: Forbidden media permissions in {manifest}: {sorted(bad)}')
    print(f'OK: No broad media permissions in {manifest}')
print(f'Google Play media policy check passed ({len(manifests)} release manifest(s))')
