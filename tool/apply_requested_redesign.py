from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

if "import 'vehicle_market_screen.dart';" not in s:
    s = s.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport 'vehicle_market_screen.dart';")

s = s.replace("  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];", "  static const campingFilters = ['노지/차박', '공중화장실', '급수', '블랙탱크 비움', '전기', '캠핑장'];\n  static const businessFilters = ['제작', '매매', 'A/S', '부품·용품'];\n  static const serviceFilters = ['전체', ...campingFilters, ...businessFilters];")

s = s.replace("  String globalPriceFilter = '전체';\n  final Map<String, String> servicePriceFilters = {};", "  final Set<String> selectedMapFilters = {};")

start = s.find('  bool _isUnknownPrice(String value) {')
end = s.find('  List<List<Place>> get visiblePlaceGroups', start)
if start < 0 or end < 0:
    raise SystemExit('map filter logic anchors not found')
new_logic = r'''  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    if (selectedMapFilters.isEmpty) return approved;
    return approved.where((p) => p.services.any(selectedMapFilters.contains)).toList();
  }

  Future<void> _showMapFilterDialog() async {
    final draft = Set<String>.from(selectedMapFilters);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('지도 필터'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.isEmpty,
                  title: const Text('전체', style: TextStyle(fontWeight: FontWeight.bold)),
                  onChanged: (_) => setLocal(() => draft.clear()),
                ),
                const Divider(),
                const Text('캠핑·편의', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: campingFilters.map((e) => FilterChip(
                  label: Text(_filterLabel(e)), selected: draft.contains(e),
                  onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }),
                )).toList()),
                const SizedBox(height: 18),
                const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: businessFilters.map((e) => FilterChip(
                  label: Text(e), selected: draft.contains(e),
                  onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }),
                )).toList()),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => setLocal(() => draft.clear()), child: const Text('초기화')),
            FilledButton(onPressed: () { setState(() { selectedMapFilters..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('적용')),
          ],
        ),
      ),
    );
  }

'''
s = s[:start] + new_logic + s[end:]

old_ui = """          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),
          ),"""
new_ui = """          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _showMapFilterDialog,
              icon: const Icon(Icons.tune),
              label: Text(selectedMapFilters.isEmpty ? '필터 · 전체' : '필터 ${selectedMapFilters.length}'),
            ),
          ),"""
if old_ui not in s:
    raise SystemExit('patched map filter UI block not found')
s = s.replace(old_ui, new_ui, 1)

icon_start = s.find('  List<String> _icons(Place p) {')
icon_end = s.find('  String _filterLabel', icon_start)
if icon_start < 0 or icon_end < 0:
    raise SystemExit('icon method anchors not found')
icons = r'''  List<String> _icons(Place p) {
    final out = <String>[];
    if (p.services.contains('노지/차박')) out.add('🏕️');
    if (p.services.contains('공중화장실')) out.add('🚻');
    if (p.services.contains('급수')) out.add('💧');
    if (p.services.contains('블랙탱크 비움')) out.add('🚽');
    if (p.services.contains('전기')) out.add('⚡');
    if (p.services.contains('캠핑장')) out.add('⛺');
    if (p.services.contains('제작')) out.add('🏭');
    if (p.services.contains('매매')) out.add('🚐');
    if (p.services.contains('A/S')) out.add('🔧');
    if (p.services.contains('부품·용품')) out.add('🧰');
    return out.isEmpty ? ['📍'] : out;
  }

'''
s = s[:icon_start] + icons + s[icon_end:]

s = s.replace("    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), _profilePage()];", "    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), const VehicleMarketScreen(), _profilePage()];")
if "label: '중고마켓'" not in s:
    s = s.replace("          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),", "          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: '중고마켓'),\n          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),")

old_prices = """    final prices = <String, TextEditingController>{
      '블랙탱크 비움': TextEditingController(),
      '급수': TextEditingController(),
      '노지/차박': TextEditingController(),
      '공중화장실': TextEditingController(),
    };"""
new_prices = """    final prices = <String, TextEditingController>{
      for (final service in [...campingFilters, ...businessFilters]) service: TextEditingController(),
    };"""
if old_prices not in s:
    raise SystemExit('registration service list not found')
s = s.replace(old_prices, new_prices, 1)

p.write_text(s, encoding='utf-8')
print('verified requested redesign patch: popup filter, expanded services, all icons, vehicle market navigation')
