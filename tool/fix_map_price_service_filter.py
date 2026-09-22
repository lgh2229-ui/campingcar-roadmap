from pathlib import Path

# Current source already contains the map filter UI and admin controls. This
# build-time compatibility step must tolerate later redesigns instead of
# failing on exact text/spacing changes.
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

# Only patch the legacy single-filter implementation when the exact legacy
# anchors are still present. Otherwise leave the current implementation alone.
old_state = "  String filter = '전체';\n  String savedFilter = '전체';"
old_visible = """  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    final rows = filter == '전체' ? approved : approved.where((p) => p.services.contains(filter)).toList();
    return rows;
  }
"""
old_ui = """          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"""

if old_state in s and old_visible in s and old_ui in s:
    s = s.replace(old_state, "  String globalPriceFilter = '전체';\n  final Map<String, String> servicePriceFilters = {};\n  String savedFilter = '전체';", 1)
    new_logic = """  bool _isUnknownPrice(String value) {
    final v = value.trim();
    return v.isEmpty || v.contains('확인 필요') || v.contains('정보 없음') || v.contains('금액정보 없음');
  }

  bool _priceMatches(Place p, String service, String priceFilter) {
    if (priceFilter == '전체') return true;
    final value = '${p.prices[service] ?? ''}'.trim();
    if (_isUnknownPrice(value)) return false;
    final isFree = value.contains('무료');
    return priceFilter == '무료' ? isFree : !isFree;
  }

  bool _matchesGlobalPrice(Place p) {
    if (globalPriceFilter == '전체') return true;
    for (final service in p.services) {
      if (_priceMatches(p, service, globalPriceFilter)) return true;
    }
    return false;
  }

  bool _matchesSelectedServices(Place p) {
    if (servicePriceFilters.isEmpty) return true;
    for (final entry in servicePriceFilters.entries) {
      if (!p.services.contains(entry.key)) return false;
      if (!_priceMatches(p, entry.key, entry.value)) return false;
    }
    return true;
  }

  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    return approved.where((p) => _matchesGlobalPrice(p) && _matchesSelectedServices(p)).toList();
  }

  Future<void> _openMapFilterMenu(String service) async {
    final current = service == '전체' ? globalPriceFilter : servicePriceFilters[service];
    final selected = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ...['전체', '유료', '무료'].map((price) => ListTile(title: Text(price), trailing: current == price ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(ctx, price))),
      if (service != '전체' && servicePriceFilters.containsKey(service)) TextButton.icon(onPressed: () => Navigator.pop(ctx, '__clear__'), icon: const Icon(Icons.remove_circle_outline), label: const Text('이 항목 필터 해제')),
    ])));
    if (selected == null || !mounted) return;
    setState(() {
      if (service == '전체') globalPriceFilter = selected;
      else if (selected == '__clear__' || selected == '전체') servicePriceFilters.remove(service);
      else servicePriceFilters[service] = selected;
    });
  }

  Widget _mapFilterButton(String service) {
    final active = service == '전체' ? globalPriceFilter != '전체' : servicePriceFilters.containsKey(service);
    final price = service == '전체' ? globalPriceFilter : servicePriceFilters[service];
    final sub = price != null && price != '전체' ? ' · $price' : '';
    return Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text('${_filterLabel(service)}$sub'), selected: active, onSelected: (_) => _openMapFilterMenu(service)));
  }
"""
    s = s.replace(old_visible, new_logic, 1)
    s = s.replace(old_ui, "          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map(_mapFilterButton).toList())),", 1)
    p.write_text(s, encoding='utf-8')
    print('patched legacy map filters')
else:
    print('current map filter implementation retained')

# Admin controls were redesigned into a column with management/approval/report
# buttons. Move the whole group only when the old top offset is present; never
# fail if another patch/redesign already moved it.
p = Path('lib/screens/admin_home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/admin_home_screen.dart')
s = p.read_text(encoding='utf-8')
old = 'Positioned(top:MediaQuery.of(context).padding.top+12,right:12'
new = 'Positioned(top:MediaQuery.of(context).padding.top+118,right:12'
if old in s:
    p.write_text(s.replace(old, new, 1), encoding='utf-8')
    print('moved admin control group below map filters')
else:
    print('admin control position already redesigned/moved')
