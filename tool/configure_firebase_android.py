from pathlib import Path
p=Path('android/settings.gradle.kts')
if p.exists():
 s=p.read_text()
 marker='    id("dev.flutter.flutter-plugin-loader") version "1.0.0"'
 if 'com.google.gms.google-services' not in s and marker in s:
  s=s.replace(marker, marker+'\n    id("com.google.gms.google-services") version "4.4.4" apply false')
 p.write_text(s)
p=Path('android/app/build.gradle.kts')
if p.exists():
 s=p.read_text()
 marker='    id("dev.flutter.flutter-gradle-plugin")'
 if 'com.google.gms.google-services' not in s and marker in s:
  s=s.replace(marker, marker+'\n    id("com.google.gms.google-services")')
 p.write_text(s)
