from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
"  String filter = '전체';\n  String savedFilter = '전체';",
"  String filter = '전체';\n  String priceFilter = '전체';\n  String savedFilter = '전체';"
)

old = """  List<Place> get visiblePlaces {\n    final rows = filter == '전체' ? places : places.where((p) => p.services.contains(filter)).toList();\n    return rows;\n  }\n"""
new = """  bool _isUnknownPrice(String value) {\n    final v = value.trim();\n    return v.isEmpty || v.contains('확인 필요') || v.contains('정보 없음') || v.contains('금액정보 없음');\n  }\n\n  bool _serviceMatchesPrice(Place p, String service) {\n    final value = '${p.prices[service] ?? ''}'.trim();\n    if (priceFilter == '전체') return true;\n    if (_isUnknownPrice(value)) return false;\n    final isFree = value.contains('무료');\n    return priceFilter == '무료' ? isFree : !isFree;\n  }\n\n  List<Place> get visiblePlaces {\n    return places.where((p) {\n      if (filter != '전체') {\n        if (!p.services.contains(filter)) return false;\n        return _serviceMatchesPrice(p, filter);\n      }\n      if (priceFilter == '전체') return true;\n      for (final service in p.services) {\n        if (_serviceMatchesPrice(p, service)) return true;\n      }\n      return false;\n    }).toList();\n  }\n\n  Future<void> _openMapFilterMenu(String service) async {\n    final selected = await showModalBottomSheet<String>(\n      context: context,\n      showDragHandle: true,\n      builder: (ctx) => SafeArea(\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            Padding(\n              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),\n              child: Row(children: [\n                Expanded(child: Text('${_filterLabel(service)} 필터', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),\n                Text('요금 선택', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),\n              ]),\n            ),\n            ...['전체', '유료', '무료'].map((price) => ListTile(\n                  leading: Icon(price == '전체' ? Icons.apps : price == '유료' ? Icons.payments_outlined : Icons.money_off_outlined),\n                  title: Text(price),\n                  trailing: filter == service && priceFilter == price ? const Icon(Icons.check) : null,\n                  onTap: () => Navigator.pop(ctx, price),\n                )),\n            const SizedBox(height: 8),\n          ],\n        ),\n      ),\n    );\n    if (selected == null || !mounted) return;\n    setState(() {\n      filter = service;\n      priceFilter = selected;\n    });\n  }\n\n  Widget _mapFilterButton(String service) {\n    final active = filter == service;\n    final sub = active && priceFilter != '전체' ? ' · $priceFilter' : '';\n    return Padding(\n      padding: const EdgeInsets.only(right: 6),\n      child: FilterChip(\n        label: Row(mainAxisSize: MainAxisSize.min, children: [Text('${_filterLabel(service)}$sub'), const SizedBox(width: 2), const Icon(Icons.arrow_drop_down, size: 18)]),\n        selected: active,\n        onSelected: (_) => _openMapFilterMenu(service),\n      ),\n    );\n  }\n"""
if old not in s:
    raise SystemExit('visiblePlaces block not found')
s = s.replace(old, new)

old_ui = """          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),"""
new_ui = """          SingleChildScrollView(\n            scrollDirection: Axis.horizontal,\n            child: Row(children: serviceFilters.map(_mapFilterButton).toList()),\n          ),"""
if old_ui not in s:
    raise SystemExit('map filter UI block not found')
s = s.replace(old_ui, new_ui, 1)

p.write_text(s, encoding='utf-8')
print('patched map service filters with all/paid/free submenus')
