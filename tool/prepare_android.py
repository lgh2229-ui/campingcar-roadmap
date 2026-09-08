from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text(encoding='utf-8')
perms = '''    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n    <uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />\n'''
if 'android.permission.ACCESS_FINE_LOCATION' not in s:
    s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + perms)
s = s.replace('android:label="campingcar_roadmap"', 'android:label="캠핑카족 로드맵"')
p.write_text(s, encoding='utf-8')

# Google Play 2026 target requirement: ensure API 36 where Flutter template allows it.
# Also use a permanent applicationId that can be installed beside legacy randomly-signed builds.
# Keep the generated namespace unchanged so MainActivity continues to resolve normally.
for gradle_name in ['android/app/build.gradle.kts', 'android/app/build.gradle']:
    gp = Path(gradle_name)
    if not gp.exists():
        continue
    g = gp.read_text(encoding='utf-8')
    g = g.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
    g = g.replace('targetSdk = flutter.targetSdkVersion', 'targetSdk = 36')
    g = g.replace('compileSdkVersion flutter.compileSdkVersion', 'compileSdkVersion 36')
    g = g.replace('targetSdkVersion flutter.targetSdkVersion', 'targetSdkVersion 36')
    g = g.replace('applicationId = "kr.co.campingcarroadmap.campingcar_roadmap"', 'applicationId = "kr.co.campingcarroadmap.app"')
    g = g.replace("applicationId 'kr.co.campingcarroadmap.campingcar_roadmap'", "applicationId 'kr.co.campingcarroadmap.app'")
    g = g.replace('applicationId "kr.co.campingcarroadmap.campingcar_roadmap"', 'applicationId "kr.co.campingcarroadmap.app"')
    gp.write_text(g, encoding='utf-8')
