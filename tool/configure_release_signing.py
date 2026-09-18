from pathlib import Path

app = Path('android/app')
gp = app / 'build.gradle.kts'
if not gp.exists():
    raise SystemExit('android/app/build.gradle.kts not found')

s = gp.read_text(encoding='utf-8')

if 'import java.util.Properties' not in s:
    s = 'import java.util.Properties\nimport java.io.FileInputStream\n\n' + s

marker = 'android {\n'
if marker not in s:
    raise SystemExit('android block not found')

setup = '''android {\n    val keystoreProperties = Properties()\n    val keystorePropertiesFile = rootProject.file("key.properties")\n    if (keystorePropertiesFile.exists()) {\n        keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n    }\n'''
s = s.replace(marker, setup, 1)

if 'create("release")' not in s:
    # Current Flutter templates may use buildTypes { or buildTypes{ formatting.
    idx = s.find('buildTypes {')
    if idx < 0:
        raise SystemExit('buildTypes block not found')
    line_start = s.rfind('\n', 0, idx) + 1
    indent = s[line_start:idx]
    block = f'''{indent}signingConfigs {{\n{indent}    create("release") {{\n{indent}        keyAlias = keystoreProperties["keyAlias"] as String?\n{indent}        keyPassword = keystoreProperties["keyPassword"] as String?\n{indent}        storeFile = keystoreProperties["storeFile"]?.let {{ file(it) }}\n{indent}        storePassword = keystoreProperties["storePassword"] as String?\n{indent}    }}\n{indent}}}\n\n'''
    s = s[:line_start] + block + s[line_start:]

# Replace Flutter's default debug signing only after release config exists.
s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')

# Fail early if the patch did not produce the required config.
if 'create("release")' not in s or 'signingConfigs.getByName("release")' not in s:
    raise SystemExit('release signing patch incomplete')

gp.write_text(s, encoding='utf-8')
