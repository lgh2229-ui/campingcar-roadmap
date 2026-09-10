from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
"  String filter = '전체';\n  String savedFilter = '전체';",
"  String filter = '전체';\n  String priceFilter = '전체';\n  String savedFilter = '전체';"
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

  bool _serviceMatchesPrice(Place p, String service) {
    final value = '${p.prices[service] ?? ''}'.trim();
    if (priceFilter == '전체') return true;
    if (_isUnknownPrice(value)) return false;
    final isFree = value.contains('무료');
    return priceFilter == '무료' ? isFree : !isFree;
  }

  List<Place> get visiblePlaces {
    final approved = places.where((p) => p.isApproved).toList();
    return approved.where((p) {
      if (filter != '전체') {
        if (!p.services.contains(filter)) return false;
        return _serviceMatchesPrice(p, filter);
      }
      if (priceFilter == '전체') return true;
      for (final service in p.services) {
        if (_serviceMatchesPrice(p, service)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _openMapFilterMenu(String service) async {
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
                  trailing: filter == service && priceFilter == price ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, price),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      filter = service;
      priceFilter = selected;
    });
  }

  Widget _mapFilterButton(String service) {
    final active = filter == service;
    final sub = active && priceFilter != '전체' ? ' · $priceFilter' : '';
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
print('patched map service filters with all/paid/free submenus')
