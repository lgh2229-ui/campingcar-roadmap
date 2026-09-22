from pathlib import Path

# Mobile Ads is currently disabled for release stability.
# Do not add or initialize MobileAds here. This script only removes any stale
# initialization left by an older patch before applying the location fix.
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
s = s.replace('  await MobileAds.instance.initialize();\n', '')
s = s.replace('  MobileAds.instance.initialize().catchError((_) {});\n', '')
s = s.replace('  // Ads are optional. Never prevent app startup if the SDK is slow/fails.\n', '')
p.write_text(s, encoding='utf-8')

# Persist and render the exact GPS point when My Location is pressed.
p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
if 'LatLng? currentLocation;' not in s:
    s = s.replace('  LatLng? selectedSpot;\n', '  LatLng? selectedSpot;\n  LatLng? currentLocation;\n', 1)
s = s.replace('''      center = LatLng(p.latitude, p.longitude);
      map.move(center, 15);''', '''      center = LatLng(p.latitude, p.longitude);
      currentLocation = center;
      map.move(center, 17);''')
anchor = '''              if (selectedSpot != null)
                Marker(point: selectedSpot!, width: 100, height: 75, alignment: Alignment.topCenter, child: const Column(children: [Text('등록 위치', style: TextStyle(fontWeight: FontWeight.bold)), Icon(Icons.location_pin, color: Colors.red, size: 48)])),'''
marker = '''              if (currentLocation != null)
                Marker(
                  point: currentLocation!,
                  width: 34,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.blue, width: 3),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                    ),
                    child: const Center(child: Icon(Icons.circle, color: Colors.blue, size: 14)),
                  ),
                ),
              if (selectedSpot != null)
                Marker(point: selectedSpot!, width: 100, height: 75, alignment: Alignment.topCenter, child: const Column(children: [Text('등록 위치', style: TextStyle(fontWeight: FontWeight.bold)), Icon(Icons.location_pin, color: Colors.red, size: 48)])),'''
if anchor in s and 'point: currentLocation!' not in s:
    s = s.replace(anchor, marker, 1)
p.write_text(s, encoding='utf-8')
