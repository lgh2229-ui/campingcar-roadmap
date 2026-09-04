from pathlib import Path
import os

app = Path('android/app')
# Supports the current Flutter Kotlin Gradle template. The workflow writes
# android/key.properties from GitHub Secrets before this patch runs.
gp = app / 'build.gradle.kts'
if gp.exists():
    s = gp.read_text(encoding='utf-8')
    if 'java.util.Properties' not in s:
        s = 'import java.util.Properties\nimport java.io.FileInputStream\n\n' + s
    marker = 'android {\n'
    setup = '''android {\n    val keystoreProperties = Properties()\n    val keystorePropertiesFile = rootProject.file("key.properties")\n    if (keystorePropertiesFile.exists()) {\n        keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n    }\n'''
    s = s.replace(marker, setup, 1)
    if 'signingConfigs {' not in s:
        needle = '    buildTypes {\n'
        block = '''    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String?\n            keyPassword = keystoreProperties["keyPassword"] as String?\n            storeFile = keystoreProperties["storeFile"]?.let { file(it) }\n            storePassword = keystoreProperties["storePassword"] as String?\n        }\n    }\n\n    buildTypes {\n'''
        s = s.replace(needle, block, 1)
    # Flutter template normally signs release with debug. Replace only that line.
    s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    gp.write_text(s, encoding='utf-8')
else:
    raise SystemExit('android/app/build.gradle.kts not found; update signing patch for template')
