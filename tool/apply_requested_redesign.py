from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

if "import 'vehicle_market_screen.dart';" not in s:
    s = s.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport 'vehicle_market_screen.dart';")

s = s.replace(
    "  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];",
    "  static const campingFilters = ['노지/차박', '공중화장실', '급수', '블랙탱크 비움'];\n"
    "  static const businessFilters = ['제작', '매매', 'A/S', '부품·용품'];\n"
    "  static const serviceFilters = ['전체', ...campingFilters, ...businessFilters];",
)
if '  final Set<String> selectedMapFilters = {};' not in s:
    s = s.replace('class _HomeScreenState extends State<HomeScreen> {', "class _HomeScreenState extends State<HomeScreen> {\n  final Set<String> selectedMapFilters = {};\n  final Map<String, String> mapServicePriceFilters = {};", 1)
s = s.replace("  String filter = '전체';\n", '')

start = s.find('  bool _isMine(Place p)')
end = s.find('  List<List<Place>> get visiblePlaceGroups', start)
if start < 0 or end < 0:
    raise SystemExit('filter anchors missing')
logic = r'''  bool _isMine(Place p) => p.ownerId == _currentAuthorId;

  bool _servicePriceMatches(Place p, String service, String price) {
    if (!p.services.contains(service)) return false;
    if (price == '전체') return true;
    final value = '${p.prices[service] ?? ''}'.trim();
    if (value.isEmpty || value.contains('정보 없음') || value.contains('확인 필요') || value.contains('금액정보 없음')) return false;
    final isFree = value.contains('무료');
    return price == '무료' ? isFree : !isFree;
  }

  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    if (selectedMapFilters.isEmpty) return approved;
    return approved.where((p) {
      for (final service in selectedMapFilters) {
        if (_servicePriceMatches(p, service, mapServicePriceFilters[service] ?? '전체')) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _showMapFilterDialog() async {
    final draft = Set<String>.from(selectedMapFilters);
    final draftPrices = Map<String, String>.from(mapServicePriceFilters);
    Widget serviceRow(String service, void Function(void Function()) setLocal) {
      final selected = draft.contains(service);
      final price = draftPrices[service] ?? '전체';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 135, child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading, title: Text(_filterLabel(service), maxLines: 1, softWrap: false), value: selected, onChanged: (v) => setLocal(() {
            if (v == true) { draft.add(service); draftPrices.putIfAbsent(service, () => '전체'); } else { draft.remove(service); draftPrices.remove(service); }
          }))),
          if (selected) Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['전체','무료','유료'].map<Widget>((e) => Flexible(child: InkWell(onTap: () => setLocal(() => draftPrices[service] = e), child: Row(mainAxisSize: MainAxisSize.min, children: [Radio<String>(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), value: e, groupValue: price, onChanged: (v) => setLocal(() => draftPrices[service] = v ?? '전체')), Text(e, maxLines: 1, softWrap: false)])))).toList())),
        ]),
      );
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('지도 필터'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: draft.isEmpty, title: const Text('전체', style: TextStyle(fontWeight: FontWeight.bold)), onChanged: (_) => setLocal(() { draft.clear(); draftPrices.clear(); })),
            const Divider(),
            const Text('캠핑·편의', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...campingFilters.map((e) => serviceRow(e, setLocal)),
            const SizedBox(height: 12),
            const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: businessFilters.map((e) => FilterChip(label: Text(e == '부품·용품' ? '부품/용품' : e), selected: draft.contains(e), onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); draftPrices.remove(e); } }))).toList()),
          ]))),
          actions: [
            TextButton(onPressed: () => setLocal(() { draft.clear(); draftPrices.clear(); }), child: const Text('초기화')),
            FilledButton(onPressed: () { setState(() { selectedMapFilters..clear()..addAll(draft); mapServicePriceFilters..clear()..addAll(draftPrices); }); Navigator.pop(ctx); }, child: const Text('적용')),
          ],
        ),
      ),
    );
  }

  Widget _serviceAvailability(Place p) {
    const items = <(String, String)>[('제작', '제작'), ('매매', '매매'), ('A/S', 'A/S'), ('부품·용품', '부품/용품')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      ...items.map((x) { final available = p.services.contains(x.$1); return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [SizedBox(width: 105, child: Text('${x.$2} :', style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(available ? '가능' : '이용불가'))])); }),
    ]);
  }

'''
s = s[:start] + logic + s[end:]
old_choice = "          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"
old_helper = "          SingleChildScrollView(\n            scrollDirection: Axis.horizontal,\n            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),\n          ),"
new_filter = "          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _showMapFilterDialog, icon: const Icon(Icons.tune), label: Text(selectedMapFilters.isEmpty ? '필터 · 전체' : '필터 ${selectedMapFilters.length}'))),"
if old_choice in s:
    s = s.replace(old_choice, new_filter, 1)
elif old_helper in s:
    s = s.replace(old_helper, new_filter, 1)

icon_start = s.find('  List<String> _icons(Place p) {')
icon_end = s.find('  String _filterLabel', icon_start)
if icon_start >= 0 and icon_end >= 0:
    icon_code = r'''  List<String> _icons(Place p) {
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
    s = s[:icon_start] + icon_code + s[icon_end:]

s = s.replace("    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), _profilePage()];", "    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), const VehicleMarketScreen(), _profilePage()];")
if "label: '중고마켓'" not in s:
    s = s.replace("          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),", "          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: '중고마켓'),\n          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),")

if '_serviceAvailability(p),' not in s:
    anchors = [
        "        const Text('이용가능 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),",
        "        const Text('이용안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),",
    ]
    inserted = False
    for anchor in anchors:
        if anchor in s:
            s = s.replace(anchor, "        _serviceAvailability(p),\n" + anchor, 1)
            inserted = True
            break
    if not inserted:
        raise SystemExit('usage information anchor missing')

s = s.replace("const Text('이용가능 서비스'", "const Text('이용안내'")
s = s.replace("Text('이용가능 서비스'", "Text('이용안내'")
s = s.replace("if (p.address.isNotEmpty) Text(p.address),", "if (p.address.isNotEmpty) Text('주소 : ${p.address}'),")
s = s.replace("        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),", "        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),\n        if (p.phone.isNotEmpty && p.note.isNotEmpty) const SizedBox(height: 12),")

new_prices = "    final prices = <String, TextEditingController>{for (final service in [...campingFilters, ...businessFilters]) service: TextEditingController()};"
pat = re.compile(r"    final prices = <String, TextEditingController>\{.*?\};", re.S)
if pat.search(s):
    s = pat.sub(new_prices, s, count=1)

p.write_text(s, encoding='utf-8')
print('requested redesign applied cleanly; vehicle market repair handled by prior build step')
