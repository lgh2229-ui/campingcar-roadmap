"""Enable release-only R8 code/resource shrinking on the generated Flutter Android app.

Flutter's android/ directory is generated in CI. Run this AFTER flutter create,
pin_android_toolchain.py and prepare_android.py and BEFORE flutter build.
Use optimized shrinking on AGP 8.13 rather than an incompatible AGP 9 upgrade.
"""
from pathlib import Path
import re

gradle = Path("android/app/build.gradle.kts")
properties = Path("android/gradle.properties")

if not gradle.is_file() or not properties.is_file():
    raise SystemExit("Generated Android Gradle configuration is missing")

src = gradle.read_text(encoding="utf-8")
release = re.search(r'(?m)^([ \t]*)(?:release|getByName\("release"\))[ \t]*\{[ \t]*$', src)
if release is None:
    raise SystemExit("Cannot find release buildType in generated Kotlin Gradle file")

indent = release.group(1) + "    "
# Flutter's generated template does not normally set these flags. Fail rather
# than leave duplicate/conflicting options when its template changes.
release_end = src.find("\n" + release.group(1) + "}", release.end())
if release_end < 0:
    raise SystemExit("Release block closing brace not found")
body = src[release.end():release_end]
for setting in ("isMinifyEnabled", "isShrinkResources", "proguardFiles"):
    if re.search(r"\b" + setting + r"\b", body):
        raise SystemExit(f"Release {setting} already present; review the template before enabling optimization")

add = (
    "\n" + indent + "isMinifyEnabled = true"
    + "\n" + indent + "isShrinkResources = true"
    + "\n" + indent + 'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
)
src = src[:release.end()] + add + src[release.end():]
gradle.write_text(src, encoding="utf-8")

rules = Path("android/app/proguard-rules.pro")
if not rules.exists():
    rules.write_text(
        "# Release R8 optimizations. Library-specific consumer rules remain active.\n"
        "# Add narrow keep rules only if release runtime tests reveal a need.\n",
        encoding="utf-8",
    )

p = properties.read_text(encoding="utf-8")
p, count = re.subn(r"(?m)^android\.r8\.optimizedResourceShrinking=.*$",
                   "android.r8.optimizedResourceShrinking=true", p)
if count == 0:
    p = p.rstrip() + "\nandroid.r8.optimizedResourceShrinking=true\n"
p = re.sub(r"(?m)^android\.enableR8\.fullMode=false\s*\n?", "", p)
properties.write_text(p, encoding="utf-8")

print("Release: R8 minify + optimized resource shrink enabled (AGP 8.13 compatible).")
