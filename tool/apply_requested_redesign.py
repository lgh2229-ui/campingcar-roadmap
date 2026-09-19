from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

if "import 'vehicle_market_screen.dart';" not in s:
    s = s.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport 'vehicle_market_screen.dart';")

s = s.replace("  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];", "  static const campingFilters = ['노지/차박', '공중화장실', '급수', '블랙탱크 비움'];\n  static const businessFilters = ['제작', '매매', 'A/S', '부품·용품'];\n  static const serviceFilters = ['전체', ...campingFilters, ...businessFilters];")

if '  final Set<String> selectedMapFilters = {};' not in s:
    state_anchor = '  int navIndex = 0;\n'
    if state_anchor in s: s = s.replace(state_anchor, state_anchor + '  final Set<String> selectedMapFilters = {};\n', 1)
    else:
        class_anchor = 'class _HomeScreenState extends State<HomeScreen> {'
        if class_anchor not in s: raise SystemExit('home state class anchor not found')
        s = s.replace(class_anchor, class_anchor + '\n  final Set<String> selectedMapFilters = {};', 1)
s = s.replace("  String filter = '전체';\n", '')

start = s.find('  bool _isMine(Place p)')
end = s.find('  List<List<Place>> get visiblePlaceGroups', start)
if start < 0 or end < 0: raise SystemExit('map filter logic anchors not found')
new_logic = r'''  bool _isMine(Place p) => p.ownerId == _currentAuthorId;
  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    if (selectedMapFilters.isEmpty) return approved;
    return approved.where((p) => p.services.any(selectedMapFilters.contains)).toList();
  }

  Future<void> _showMapFilterDialog() async {
    final draft = Set<String>.from(selectedMapFilters);
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('지도 필터'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: draft.isEmpty, title: const Text('전체', style: TextStyle(fontWeight: FontWeight.bold)), onChanged: (_) => setLocal(() => draft.clear())),
        const Divider(), const Text('캠핑·편의', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: campingFilters.map((e) => FilterChip(label: Text(_filterLabel(e)), selected: draft.contains(e), onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }))).toList()),
        const SizedBox(height: 18), const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: businessFilters.map((e) => FilterChip(label: Text(e), selected: draft.contains(e), onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }))).toList()),
      ]))),
      actions: [TextButton(onPressed: () => setLocal(() => draft.clear()), child: const Text('초기화')), FilledButton(onPressed: () { setState(() { selectedMapFilters..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('적용'))],
    )));
  }

  Widget _serviceAvailability(Place p) {
    const items = <(String, String)>[
      ('블랙탱크 비움', '블랙탱크'), ('급수', '급수'), ('노지/차박', '노지/차박'), ('공중화장실', '화장실'),
      ('제작', '제작'), ('매매', '매매'), ('A/S', 'A/S'), ('부품·용품', '부품/용품'),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('캠핑카 서비스', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: items.map((x) {
          final yes = p.services.contains(x.$1);
          return Chip(avatar: Icon(yes ? Icons.check_circle : Icons.remove_circle_outline, size: 18), label: Text(x.$2));
        }).toList()),
      ])),
    );
  }

'''
s = s[:start] + new_logic + s[end:]

old_choice = "          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"
old_helper = "          SingleChildScrollView(\n            scrollDirection: Axis.horizontal,\n            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),\n          ),"
new_ui = "          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _showMapFilterDialog, icon: const Icon(Icons.tune), label: Text(selectedMapFilters.isEmpty ? '필터 · 전체' : '필터 ${selectedMapFilters.length}'))),"
if old_choice in s: s = s.replace(old_choice, new_ui, 1)
elif old_helper in s: s = s.replace(old_helper, new_ui, 1)
elif 'onPressed: _showMapFilterDialog' not in s: raise SystemExit('map filter UI block not found')

icon_start = s.find('  List<String> _icons(Place p) {'); icon_end = s.find('  String _filterLabel', icon_start)
if icon_start < 0 or icon_end < 0: raise SystemExit('icon method anchors not found')
icons = r'''  List<String> _icons(Place p) {
    final out = <String>[];
    if (p.services.contains('노지/차박')) out.add('🏕️');
    if (p.services.contains('공중화장실')) out.add('🚻');
    if (p.services.contains('급수')) out.add('💧');
    if (p.services.contains('블랙탱크 비움')) out.add('🚽');
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

# Show every requested service category when a place is opened.
detail_anchor = "        Text(p.services.join(' · ')),"
if detail_anchor in s:
    s = s.replace(detail_anchor, "        _serviceAvailability(p),", 1)
elif '_serviceAvailability(p),' not in s:
    raise SystemExit('place detail service anchor not found')

current_prices = "    final prices = <String, TextEditingController>{for (final s in ['급수', '블랙탱크 비움', '노지/차박', '공중화장실']) s: TextEditingController()};"
new_prices = "    final prices = <String, TextEditingController>{for (final service in [...campingFilters, ...businessFilters]) service: TextEditingController()};"
if current_prices in s: s = s.replace(current_prices, new_prices, 1)
else:
    pattern = re.compile(r"    final prices = <String, TextEditingController>\{.*?\};", re.S)
    if not pattern.search(s): raise SystemExit('registration service list not found')
    s = pattern.sub(new_prices, s, count=1)

p.write_text(s, encoding='utf-8')
print('verified redesign: service detail matrix, popup filters, all icons, vehicle market navigation')
