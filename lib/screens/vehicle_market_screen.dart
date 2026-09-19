import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleMarketScreen extends StatefulWidget {
  const VehicleMarketScreen({super.key});

  @override
  State<VehicleMarketScreen> createState() => _VehicleMarketScreenState();
}

class _VehicleMarketScreenState extends State<VehicleMarketScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _db.from('vehicle_market_listings').select().eq('status', 'active').order('created_at', ascending: false);
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _rows;
    final q = _query.toLowerCase();
    return _rows.where((x) => '${x['title']} ${x['manufacturer']} ${x['model']} ${x['region']}'.toLowerCase().contains(q)).toList();
  }

  String _money(dynamic v) {
    final n = int.tryParse('$v');
    if (n == null) return '가격 협의';
    final s = n.toString();
    return '${s.replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => ',')}원';
  }

  Future<void> _register() async {
    final title = TextEditingController();
    final maker = TextEditingController();
    final model = TextEditingController();
    final year = TextEditingController();
    final mileage = TextEditingController();
    final price = TextEditingController();
    final region = TextEditingController();
    final phone = TextEditingController();
    final desc = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('중고 캠핑카 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: const InputDecoration(labelText: '매물 제목 *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextField(controller: maker, decoration: const InputDecoration(labelText: '제조사', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: '모델명 *', border: OutlineInputBorder())))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '연식', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: mileage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '주행거리 km', border: OutlineInputBorder())))]),
          const SizedBox(height: 8),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '판매가격(원)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: region, decoration: const InputDecoration(labelText: '판매지역 *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '연락처 *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: '차량 설명', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () {
            if (title.text.trim().isEmpty || model.text.trim().isEmpty || region.text.trim().isEmpty || phone.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('필수 항목을 입력해주세요.'))); return;
            }
            Navigator.pop(ctx, true);
          }, icon: const Icon(Icons.check), label: const Text('매물 등록')),
        ])),
      ),
    );
    if (ok != true) return;
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('vehicle_market_listings').insert({
        'owner_id': uid, 'title': title.text.trim(), 'manufacturer': maker.text.trim(), 'model': model.text.trim(),
        'model_year': int.tryParse(year.text), 'mileage_km': int.tryParse(mileage.text), 'price_krw': int.tryParse(price.text),
        'region': region.text.trim(), 'phone': phone.text.trim(), 'description': desc.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('중고 캠핑카가 등록되었습니다.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('차량중고마켓')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), child: SearchBar(controller: _search, hintText: '캠핑카, 모델명 검색', leading: const Icon(Icons.search), onChanged: (v) => setState(() => _query = v.trim()))),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : rows.isEmpty
          ? Center(child: Text(_query.isEmpty ? '등록된 중고 캠핑카가 없습니다.\n아래 차량 등록 버튼으로 첫 매물을 등록해보세요.' : '검색 결과가 없습니다.', textAlign: TextAlign.center))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
              final x = rows[i];
              return Card(margin: const EdgeInsets.fromLTRB(12, 6, 12, 6), child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                title: Text('${x['title']}'),
                subtitle: Text('${x['manufacturer']} ${x['model']} · ${x['model_year'] ?? '연식미상'}\n${x['region']} · ${x['mileage_km'] ?? '-'}km'),
                trailing: Text(_money(x['price_krw']), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${x['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  Text('${x['manufacturer']} ${x['model']} · ${x['model_year'] ?? '연식미상'}'), Text('주행거리: ${x['mileage_km'] ?? '-'}km'), Text('판매지역: ${x['region']}'), Text('판매가격: ${_money(x['price_krw'])}'), Text('연락처: ${x['phone']}'),
                  if ('${x['description'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${x['description']}')),
                ])))),
              ));
            }))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _register, icon: const Icon(Icons.add), label: const Text('차량 등록')),
    );
  }
}
