from pathlib import Path
import re

# google_mobile_ads 9.1.0 itself is built/tested with AGP 9.0.0.
# Flutter 3.47 generated projects may use AGP 9.x; keep this app on the
# plugin-compatible Android toolchain until the AGP 9 path is proven stable.
settings = Path('android/settings.gradle.kts')
if settings.exists():
    s = settings.read_text(encoding='utf-8')
    s, n = re.subn(r'id\("com\.android\.application"\) version "[^"]+" apply false',
                   'id("com.android.application") version "9.0.0" apply false', s, count=1)
    if n != 1:
        raise SystemExit('AGP application plugin version marker not found')
    settings.write_text(s, encoding='utf-8')

wrapper = Path('android/gradle/wrapper/gradle-wrapper.properties')
if wrapper.exists():
    s = wrapper.read_text(encoding='utf-8')
    s, n = re.subn(r'distributionUrl=.*gradle-[^-/]+-all\.zip',
                   'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.3.1-all.zip', s, count=1)
    if n != 1:
        s, n = re.subn(r'distributionUrl=.*gradle-[^-/]+-bin\.zip',
                       'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.3.1-bin.zip', s, count=1)
    if n != 1:
        raise SystemExit('Gradle wrapper version marker not found')
    wrapper.write_text(s, encoding='utf-8')

props = Path('android/gradle.properties')
if props.exists():
    s = props.read_text(encoding='utf-8')
    s = re.sub(r'^android\.newDsl=.*$', 'android.newDsl=true', s, flags=re.M)
    s = re.sub(r'^android\.builtInKotlin=.*$', 'android.builtInKotlin=true', s, flags=re.M)
    props.write_text(s, encoding='utf-8')
print('Pinned Android build stack: AGP 9.0.0 / Gradle 9.3.1')
