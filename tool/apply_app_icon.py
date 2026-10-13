"""Install the official Campingcar Roadmap launcher and Play Store icons.

Flutter regenerates android/ during each GitHub Actions build, so this script
must run *after* `flutter create` and before the APK/AAB build.
"""
from pathlib import Path
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/brand/campingcar_signature.webp'
EXPECTED_SHA256 = '2eb15717c6c51e2dda3b36677f76017947b24cc8706fba1a1041ce78608468c6'
RES = ROOT / 'android/app/src/main/res'
PLAY_STORE = ROOT / 'play_store/campingcar_signature_512.png'

if not SOURCE.is_file():
    raise SystemExit(f'Missing official app icon: {SOURCE}')
if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != EXPECTED_SHA256:
    raise SystemExit('Official app icon checksum does not match')
if not (ROOT / 'android/app/src/main/AndroidManifest.xml').is_file():
    raise SystemExit('Run flutter create to generate android/ before applying the app icon')

with Image.open(SOURCE) as source:
    image = source.convert('RGBA')
    if image.size != (512, 512):
        raise SystemExit('Expected 512x512 square brand artwork')
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for dpi, pixels in densities.items():
        folder = RES / f'mipmap-{dpi}'
        folder.mkdir(parents=True, exist_ok=True)
        image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png', 'PNG')
    PLAY_STORE.parent.mkdir(parents=True, exist_ok=True)
    image.convert('RGB').save(PLAY_STORE, 'PNG', optimize=True)

print('Applied Campingcar Roadmap signature icon: Android mipmaps and Google Play 512x512')