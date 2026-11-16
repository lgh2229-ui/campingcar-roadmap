"""Keep WorkManager/Room reflection constructors in Android release builds.

Android Gradle Plugin 9's R8 full-mode can remove the no-argument constructor
of Room's generated WorkDatabase_Impl. AndroidX Startup initializes WorkManager
before Flutter starts, so this causes an immediate startup crash.
Run after flutter create / prepare_android.py, before flutter build.
"""
from pathlib import Path
import re

gradle = Path("android/app/build.gradle.kts")
rules_file = Path("android/app/proguard-rules.pro")
if not gradle.is_file():
    raise SystemExit("Missing generated Android app build.gradle.kts")

source = gradle.read_text(encoding="utf-8")
match = re.search(r'(?m)^([ \t]*)(?:release|getByName\("release"\))[ \t]*\{[ \t]*$', source)
if match is None:
    raise SystemExit("Cannot locate release buildType; refusing to silently skip the crash fix")

# Locate the matching release block brace without relying on its indentation.
open_brace = source.find("{", match.start(), match.end())
depth = 0
close_brace = -1
for i in range(open_brace, len(source)):
    if source[i] == "{":
        depth += 1
    elif source[i] == "}":
        depth -= 1
        if depth == 0:
            close_brace = i
            break
if close_brace < 0:
    raise SystemExit("Unterminated release buildType block")

body = source[open_brace + 1:close_brace]
if "proguardFiles(" not in body:
    ind = match.group(1) + "    "
    addition = (
        "\n" + ind +
        'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
    )
    source = source[:open_brace + 1] + addition + source[open_brace + 1:]
    gradle.write_text(source, encoding="utf-8")
elif '"proguard-rules.pro"' not in body:
    raise SystemExit("Release has custom ProGuard files without proguard-rules.pro")

# R8 full-mode may preserve the database type but strip its reflective
# zero-arg constructor. Keep the implementation and the reflected constructors.
rules = """
# BEGIN WorkManager / Room startup crash fix (AGP 9 R8 full mode)
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.InputMerger { <init>(); }
# END WorkManager / Room startup crash fix
""".lstrip()

existing = rules_file.read_text(encoding="utf-8") if rules_file.exists() else ""
if "# BEGIN WorkManager / Room startup crash fix" not in existing:
    rules_file.write_text(existing.rstrip() + "\n\n" + rules, encoding="utf-8")

# Catch missing wiring in CI before building and publishing another broken APK.
updated = gradle.read_text(encoding="utf-8")
assert '"proguard-rules.pro"' in updated
assert "WorkDatabase_Impl { *; }" in rules_file.read_text(encoding="utf-8")
print("Applied WorkManager / Room R8 startup crash keep rules to release build")
