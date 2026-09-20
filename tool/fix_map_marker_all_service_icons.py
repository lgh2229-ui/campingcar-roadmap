from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

old = """                          : Center(child: Text(_icons(p).take(3).join(), style: const TextStyle(fontSize: 18))),"""
new = """                          : Center(
                              child: Builder(builder: (_) {
                                final icons = _icons(p);
                                if (icons.length <= 2) {
                                  return Text(icons.join(), style: const TextStyle(fontSize: 18, height: 1));
                                }
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(icons.take(2).join(), style: const TextStyle(fontSize: 17, height: 1)),
                                    Text(icons.skip(2).join(), style: const TextStyle(fontSize: 14, height: 1)),
                                  ],
                                );
                              }),
                            ),"""

if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding='utf-8')
    print('patched map markers to show all service icons')
else:
    print('legacy 3-icon marker fragment not present; continuing')

# Repair the vehicle-market build method that previously had an unmatched list bracket.
v = Path('lib/screens/vehicle_market_screen.dart')
if v.exists():
    t = v.read_text(encoding='utf-8')
    marker = ' @override Widget build(BuildContext context)'
    pos = t.find(marker)
    if pos >= 0:
        fixed = r''' @override
 Widget build(BuildContext context) {
   final rows = _filtered;
   return Scaffold(
     appBar: AppBar(title: const Text('차량중고마켓')),
     body: Column(
       children: [
         Padding(
           padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
           child: Row(
             children: [
               Expanded(
                 child: SearchBar(
                   controller: _search,
                   hintText: '캠핑카, 모델명 검색',
                   leading: const Icon(Icons.search),
                   onChanged: (value) => setState(() => _query = value.trim()),
                 ),
               ),
               const SizedBox(width: 8),
               IconButton.filledTonal(
                 onPressed: _filters,
                 icon: const Icon(Icons.tune),
                 tooltip: '필터',
               ),
             ],
           ),
         ),
         Expanded(
           child: _loading
               ? const Center(child: CircularProgressIndicator())
               : rows.isEmpty
                   ? const Center(child: Text('조건에 맞는 중고 캠핑카가 없습니다.'))
                   : RefreshIndicator(
                       onRefresh: _load,
                       child: ListView.builder(
                         itemCount: rows.length,
                         itemBuilder: (context, i) {
                           final x = rows[i];
                           return Card(
                             margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                             child: ListTile(
                               leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                               title: Text('${x['title']}'),
                               subtitle: Text("${x['manufacturer']} ${x['model']} · ${x['model_year'] ?? '연식미상'}\n${x['region']} · ${x['mileage_km'] ?? '-'}km"),
                               trailing: Text(
                                 _money(x['price_krw']),
                                 style: const TextStyle(fontWeight: FontWeight.bold),
                               ),
                               onTap: () => showModalBottomSheet<void>(
                                 context: context,
                                 isScrollControlled: true,
                                 showDragHandle: true,
                                 builder: (ctx) => SafeArea(
                                   child: SingleChildScrollView(
                                     padding: const EdgeInsets.all(20),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.stretch,
                                       children: [
                                         Text('${x['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                         const SizedBox(height: 8),
                                         Text("${x['manufacturer']} ${x['model']} · ${x['model_year'] ?? '연식미상'}"),
                                         Text("주행거리: ${x['mileage_km'] ?? '-'}km"),
                                         Text("판매지역: ${x['region']}"),
                                         Text('판매가격: ${_money(x['price_krw'])}'),
                                         const SizedBox(height: 10),
                                         Text(_spec(x)),
                                         const SizedBox(height: 10),
                                         Text("연락처: ${x['phone']}"),
                                         if ('${x['description'] ?? ''}'.trim().isNotEmpty)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 10),
                                             child: Text('${x['description']}'),
                                           ),
                                       ],
                                     ),
                                   ),
                                 ),
                               ),
                             ),
                           );
                         },
                       ),
                     ),
         ),
       ],
     ),
     floatingActionButton: FloatingActionButton.extended(
       onPressed: _register,
       icon: const Icon(Icons.add),
       label: const Text('차량 등록'),
     ),
   );
 }
}'''
        v.write_text(t[:pos] + fixed + '\n', encoding='utf-8')
        print('repaired vehicle market build syntax')
