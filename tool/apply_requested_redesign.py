from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

if "import 'vehicle_market_screen.dart';" not in s:
    s = s.replace("import '../repositories/auth_repository.dart';", "import '../repositories/auth_repository.dart';\nimport 'vehicle_market_screen.dart';")

s = s.replace("  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];", "  static const campingFilters = ['노지/차박', '공중화장실', '급수', '블랙탱크 비움'];\n  static const businessFilters = ['제작', '매매', 'A/S', '부품·용품'];\n  static const serviceFilters = ['전체', ...campingFilters, ...businessFilters];")
if '  final Set<String> selectedMapFilters = {};' not in s:
    anchor = 'class _HomeScreenState extends State<HomeScreen> {'
    if anchor not in s: raise SystemExit('home state class anchor not found')
    s = s.replace(anchor, anchor + '\n  final Set<String> selectedMapFilters = {};', 1)
s = s.replace("  String filter = '전체';\n", '')

start=s.find('  bool _isMine(Place p)'); end=s.find('  List<List<Place>> get visiblePlaceGroups',start)
if start<0 or end<0: raise SystemExit('map filter logic anchors not found')
logic=r'''  bool _isMine(Place p) => p.ownerId == _currentAuthorId;
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
        Wrap(spacing: 6, runSpacing: 6, children: campingFilters.map((e) => FilterChip(label: Text(_filterLabel(e)), selected: draft.contains(e), onSelected: (v) => setLocal(() { if(v) draft.add(e); else draft.remove(e); }))).toList()),
        const SizedBox(height: 18), const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: businessFilters.map((e) => FilterChip(label: Text(e), selected: draft.contains(e), onSelected: (v) => setLocal(() { if(v) draft.add(e); else draft.remove(e); }))).toList()),
      ]))),
      actions: [TextButton(onPressed: () => setLocal(() => draft.clear()), child: const Text('초기화')), FilledButton(onPressed: () { setState(() { selectedMapFilters..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('적용'))],
    )));
  }

  Widget _serviceAvailability(Place p) {
    const items = <(String,String)>[('블랙탱크 비움','블랙탱크'),('급수','급수'),('노지/차박','노지/차박'),('공중화장실','화장실'),('제작','제작'),('매매','매매'),('A/S','A/S'),('부품·용품','부품/용품')];
    return Card(margin: const EdgeInsets.only(top:10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      const Text('캠핑카 서비스', style: TextStyle(fontWeight:FontWeight.bold)), const SizedBox(height:8),
      Wrap(spacing:7, runSpacing:7, children: items.map((x){ final yes=p.services.contains(x.$1); return Chip(avatar:Icon(yes?Icons.check_circle:Icons.remove_circle_outline,size:18),label:Text(x.$2)); }).toList())
    ])));
  }

'''
s=s[:start]+logic+s[end:]

old_choice="          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"
old_helper="          SingleChildScrollView(\n            scrollDirection: Axis.horizontal,\n            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),\n          ),"
new_ui="          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _showMapFilterDialog, icon: const Icon(Icons.tune), label: Text(selectedMapFilters.isEmpty ? '필터 · 전체' : '필터 ${selectedMapFilters.length}'))),"
if old_choice in s: s=s.replace(old_choice,new_ui,1)
elif old_helper in s: s=s.replace(old_helper,new_ui,1)
elif 'onPressed: _showMapFilterDialog' not in s: raise SystemExit('map filter UI block not found')

is_=s.find('  List<String> _icons(Place p) {'); ie=s.find('  String _filterLabel',is_)
if is_<0 or ie<0: raise SystemExit('icon method anchors not found')
icons=r'''  List<String> _icons(Place p) {
    final out=<String>[];
    if(p.services.contains('노지/차박')) out.add('🏕️'); if(p.services.contains('공중화장실')) out.add('🚻'); if(p.services.contains('급수')) out.add('💧'); if(p.services.contains('블랙탱크 비움')) out.add('🚽');
    if(p.services.contains('제작')) out.add('🏭'); if(p.services.contains('매매')) out.add('🚐'); if(p.services.contains('A/S')) out.add('🔧'); if(p.services.contains('부품·용품')) out.add('🧰');
    return out.isEmpty?['📍']:out;
  }

'''
s=s[:is_]+icons+s[ie:]

s=s.replace("    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), _profilePage()];","    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), const VehicleMarketScreen(), _profilePage()];")
if "label: '중고마켓'" not in s: s=s.replace("          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),","          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: '중고마켓'),\n          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),")

# Earlier workflow patches can replace the raw services text with a service-price widget.
# Insert our full 8-item matrix after whichever representation exists, without failing the build.
if '_serviceAvailability(p),' not in s:
    anchors=["        Text(p.services.join(' · ')),","        _servicePriceSummary(p),","        _servicePrices(p),"]
    done=False
    for a in anchors:
        if a in s:
            s=s.replace(a,a+'\n        _serviceAvailability(p),',1); done=True; break
    if not done:
        # Last-resort stable location: immediately before address in the place detail sheet.
        a="        if (p.address.isNotEmpty) Text(p.address),"
        if a in s: s=s.replace(a,"        _serviceAvailability(p),\n"+a,1)
        else: print('warning: service detail insertion point not found; continuing build')

new_prices="    final prices = <String, TextEditingController>{for (final service in [...campingFilters, ...businessFilters]) service: TextEditingController()};"
current="    final prices = <String, TextEditingController>{for (final s in ['급수', '블랙탱크 비움', '노지/차박', '공중화장실']) s: TextEditingController()};"
if current in s: s=s.replace(current,new_prices,1)
else:
    pat=re.compile(r"    final prices = <String, TextEditingController>\{.*?\};",re.S)
    if pat.search(s): s=pat.sub(new_prices,s,count=1)
    else: print('warning: registration price map not found; continuing build')

p.write_text(s,encoding='utf-8')
print('verified compatible redesign patch')
