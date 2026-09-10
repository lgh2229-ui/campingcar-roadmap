from pathlib import Path

# Map filters: keep independent service selections and require ALL selected service conditions to match.
p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
"  String filter = '전체';\n  String savedFilter = '전체';",
"  String globalPriceFilter = '전체';\n  final Map<String, String> servicePriceFilters = {};\n  String savedFilter = '전체';"
)

old = """  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    final rows = filter == '전체' ? approved : approved.where((p) => p.services.contains(filter)).toList();
    return rows;
  }
"""
new = """  bool _isUnknownPrice(String value) {
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Row(children: [
                Expanded(child: Text('${_filterLabel(service)} 필터', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                Text('요금 선택', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ]),
            ),
            ...['전체', '유료', '무료'].map((price) => ListTile(
                  leading: Icon(price == '전체' ? Icons.apps : price == '유료' ? Icons.payments_outlined : Icons.money_off_outlined),
                  title: Text(price),
                  trailing: current == price ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, price),
                )),
            if (service != '전체' && servicePriceFilters.containsKey(service))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, '__clear__'),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('이 항목 필터 해제'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (service == '전체') {
        globalPriceFilter = selected;
      } else if (selected == '__clear__') {
        servicePriceFilters.remove(service);
      } else {
        servicePriceFilters[service] = selected;
      }
    });
  }

  Widget _mapFilterButton(String service) {
    final active = service == '전체' ? globalPriceFilter != '전체' : servicePriceFilters.containsKey(service);
    final price = service == '전체' ? globalPriceFilter : servicePriceFilters[service];
    final sub = price != null && price != '전체' ? ' · $price' : '';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [Text('${_filterLabel(service)}$sub'), const SizedBox(width: 2), const Icon(Icons.arrow_drop_down, size: 18)]),
        selected: active,
        onSelected: (_) => _openMapFilterMenu(service),
      ),
    );
  }
"""
if old not in s:
    raise SystemExit('approved visiblePlaces block not found')
s = s.replace(old, new, 1)

old_ui = """          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"""
new_ui = """          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),
          ),"""
if old_ui not in s:
    raise SystemExit('map filter UI block not found')
s = s.replace(old_ui, new_ui, 1)

p.write_text(s, encoding='utf-8')
print('patched map service filters with AND multi-select paid/free submenus')

# Admin approval-list button: move it below the map search/filter strip so it no longer covers filter chips.
p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text(encoding='utf-8')
old_admin_top = "        top: MediaQuery.of(context).padding.top + 12,"
new_admin_top = "        top: MediaQuery.of(context).padding.top + 118,"
if old_admin_top not in s:
    raise SystemExit('admin approval button position pattern not found')
s = s.replace(old_admin_top, new_admin_top, 1)
p.write_text(s, encoding='utf-8')
print('moved admin approval-list button below map filters')
