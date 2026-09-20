from pathlib import Path
import re
p=Path('lib/screens/home_screen.dart');s=p.read_text(encoding='utf-8')
if "import 'vehicle_market_screen.dart';" not in s:s=s.replace("import '../repositories/auth_repository.dart';","import '../repositories/auth_repository.dart';\nimport 'vehicle_market_screen.dart';")
s=s.replace("  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];","  static const campingFilters = ['노지/차박', '공중화장실', '급수', '블랙탱크 비움'];\n  static const businessFilters = ['제작', '매매', 'A/S', '부품·용품'];\n  static const serviceFilters = ['전체', ...campingFilters, ...businessFilters];")
if '  final Set<String> selectedMapFilters = {};' not in s:
 a='class _HomeScreenState extends State<HomeScreen> {';s=s.replace(a,a+'\n  final Set<String> selectedMapFilters = {};',1)
s=s.replace("  String filter = '전체';\n",'')
start=s.find('  bool _isMine(Place p)');end=s.find('  List<List<Place>> get visiblePlaceGroups',start)
if start<0 or end<0:raise SystemExit('filter anchors missing')
logic=r'''  bool _isMine(Place p) => p.ownerId == _currentAuthorId;

  List<Place> get visiblePlaces {
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
                CheckboxListTile(contentPadding: EdgeInsets.zero, value: draft.isEmpty, title: const Text('전체', style: TextStyle(fontWeight: FontWeight.bold)), onChanged: (_) => setLocal(() => draft.clear())),
                const Divider(),
                const Text('캠핑·편의', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: campingFilters.map((e) => FilterChip(label: Text(_filterLabel(e)), selected: draft.contains(e), onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }))).toList()),
                const SizedBox(height: 18),
                const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: businessFilters.map((e) => FilterChip(label: Text(e), selected: draft.contains(e), onSelected: (v) => setLocal(() { if (v) { draft.add(e); } else { draft.remove(e); } }))).toList()),
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

  Widget _serviceAvailability(Place p) {
    const items = <(String, String)>[
      ('블랙탱크 비움','블랙탱크'), ('급수','급수'), ('노지/차박','노지/차박'), ('공중화장실','화장실'),
      ('제작','제작'), ('매매','매매'), ('A/S','A/S'), ('부품·용품','부품/용품'),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('캠핑카 서비스', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: items.map((x) {
            final yes = p.services.contains(x.$1);
            return Chip(avatar: Icon(yes ? Icons.check_circle : Icons.remove_circle_outline, size: 18), label: Text(x.$2));
          }).toList()),
        ]),
      ),
    );
  }

'''
s=s[:start]+logic+s[end:]
old="          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"
helper="          SingleChildScrollView(\n            scrollDirection: Axis.horizontal,\n            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),\n          ),"
nu="          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _showMapFilterDialog, icon: const Icon(Icons.tune), label: Text(selectedMapFilters.isEmpty ? '필터 · 전체' : '필터 ${selectedMapFilters.length}'))),"
if old in s:s=s.replace(old,nu,1)
elif helper in s:s=s.replace(helper,nu,1)
is_=s.find('  List<String> _icons(Place p) {');ie=s.find('  String _filterLabel',is_)
if is_>=0 and ie>=0:s=s[:is_]+'''  List<String> _icons(Place p) {\n    final out = <String>[];\n    if (p.services.contains('노지/차박')) out.add('🏕️');\n    if (p.services.contains('공중화장실')) out.add('🚻');\n    if (p.services.contains('급수')) out.add('💧');\n    if (p.services.contains('블랙탱크 비움')) out.add('🚽');\n    if (p.services.contains('제작')) out.add('🏭');\n    if (p.services.contains('매매')) out.add('🚐');\n    if (p.services.contains('A/S')) out.add('🔧');\n    if (p.services.contains('부품·용품')) out.add('🧰');\n    return out.isEmpty ? ['📍'] : out;\n  }\n\n'''+s[ie:]
s=s.replace("    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), _profilePage()];","    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), const VehicleMarketScreen(), _profilePage()];")
if "label: '중고마켓'" not in s:s=s.replace("          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),","          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: '중고마켓'),\n          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),")
if '_serviceAvailability(p),' not in s:
 for a in ["        Text(p.services.join(' · ')),","        _servicePriceSummary(p),","        _servicePrices(p),"]:
  if a in s:s=s.replace(a,"        _serviceAvailability(p),\n"+a,1);break
s=s.replace("const Text('이용가능 서비스'","const Text('이용안내'").replace("Text('이용가능 서비스'","Text('이용안내'")
s=s.replace("if (p.address.isNotEmpty) Text(p.address),","if (p.address.isNotEmpty) Text('주소 : ${p.address}'),")
s=s.replace("        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),","        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),\n        if (p.phone.isNotEmpty && p.note.isNotEmpty) const SizedBox(height: 12),")
new_prices="    final prices = <String, TextEditingController>{for (final service in [...campingFilters, ...businessFilters]) service: TextEditingController()};"
pat=re.compile(r"    final prices = <String, TextEditingController>\{.*?\};",re.S)
if pat.search(s):s=pat.sub(new_prices,s,count=1)
p.write_text(s,encoding='utf-8');print('applied requested place detail ordering and labels')
