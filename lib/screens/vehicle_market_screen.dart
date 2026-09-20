import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleMarketScreen extends StatefulWidget {
  const VehicleMarketScreen({super.key});
  @override
  State<VehicleMarketScreen> createState() => _VehicleMarketScreenState();
}

class _VehicleMarketScreenState extends State<VehicleMarketScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String _query = '';
  int? _minPrice, _maxPrice;
  String _toilet = '전체';
  bool? _shore;
  List<Map<String, dynamic>> _rows = [];
  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await _db.from('vehicle_market_listings').select().eq('status', 'active').order('created_at', ascending: false);
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filtered => _rows.where((x) {
    final q = _query.toLowerCase();
    if (q.isNotEmpty && !'${x['title']} ${x['manufacturer']} ${x['model']} ${x['region']}'.toLowerCase().contains(q)) return false;
    final p = int.tryParse('${x['price_krw']}');
    if (_minPrice != null && (p == null || p < _minPrice!)) return false;
    if (_maxPrice != null && (p == null || p > _maxPrice!)) return false;
    if (_toilet != '전체' && '${x['toilet_type']}' != _toilet) return false;
    if (_shore != null && x['shore_power'] != _shore) return false;
    return true;
  }).toList();

  String _money(dynamic v) {
    final n = int.tryParse('$v');
    if (n == null) return '가격 협의';
    return '${n.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',')}원';
  }

  Widget _num(TextEditingController c, String label, String unit) => TextField(
    controller: c, keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: '$label ($unit)', border: const OutlineInputBorder()),
  );

  Future<void> _filters() async {
    final min = TextEditingController(text: _minPrice?.toString() ?? '');
    final max = TextEditingController(text: _maxPrice?.toString() ?? '');
    var toilet = _toilet; bool? shore = _shore;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('매물 필터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        Row(children: [Expanded(child: _num(min, '최소금액', '원')), const SizedBox(width: 8), Expanded(child: _num(max, '최대금액', '원'))]), const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: toilet, decoration: const InputDecoration(labelText: '화장실', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: '전체', child: Text('전체')), DropdownMenuItem(value: 'none', child: Text('없음')), DropdownMenuItem(value: 'cassette', child: Text('카트리지')), DropdownMenuItem(value: 'black', child: Text('블랙'))
        ], onChanged: (v) => ss(() => toilet = v ?? '전체')), const SizedBox(height: 12),
        DropdownButtonFormField<bool?>(initialValue: shore, decoration: const InputDecoration(labelText: '한전충전', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: null, child: Text('전체')), DropdownMenuItem(value: true, child: Text('있음')), DropdownMenuItem(value: false, child: Text('없음'))
        ], onChanged: (v) => ss(() => shore = v)), const SizedBox(height: 14),
        Row(children: [Expanded(child: OutlinedButton(onPressed: () { setState(() { _minPrice=null; _maxPrice=null; _toilet='전체'; _shore=null; }); Navigator.pop(ctx); }, child: const Text('초기화'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () { setState(() { _minPrice=int.tryParse(min.text); _maxPrice=int.tryParse(max.text); _toilet=toilet; _shore=shore; }); Navigator.pop(ctx); }, child: const Text('적용')))])
      ]),
    )));
  }

  Future<void> _register() async {
    final title=TextEditingController(), maker=TextEditingController(), model=TextEditingController(), year=TextEditingController(), mileage=TextEditingController(), price=TextEditingController(), region=TextEditingController(), phone=TextEditingController(), desc=TextEditingController();
    final battery=TextEditingController(), solar=TextEditingController(), inverter=TextEditingController(), alternator=TextEditingController(), fresh=TextEditingController(), grey=TextEditingController(), toiletCap=TextEditingController();
    bool hasBattery=false, hasSolar=false, hasInverter=false, hasAlternator=false, hasFresh=false, hasGrey=false, shore=false;
    String toilet='none';
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
      Widget option(String name, bool value, void Function(bool) setValue, TextEditingController c, String unit) => Column(children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('$name ${value ? '있음' : '없음'}'), value: value, onChanged: (v) => ss(() => setValue(v))),
        if (value) Padding(padding: const EdgeInsets.only(bottom: 8), child: _num(c, '$name 용량', unit)),
      ]);
      return Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(ctx).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('중고 캠핑카 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        TextField(controller: title, decoration: const InputDecoration(labelText: '매물 제목 *', border: OutlineInputBorder())), const SizedBox(height: 8),
        Row(children: [Expanded(child: TextField(controller: maker, decoration: const InputDecoration(labelText: '제조사', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: '모델명 *', border: OutlineInputBorder())))]), const SizedBox(height: 8),
        Row(children: [Expanded(child: _num(year, '연식', '년')), const SizedBox(width: 8), Expanded(child: _num(mileage, '주행거리', 'km'))]), const SizedBox(height: 8),
        _num(price, '판매가격', '원'), const SizedBox(height: 8), TextField(controller: region, decoration: const InputDecoration(labelText: '판매지역 *', border: OutlineInputBorder())), const SizedBox(height: 8), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '연락처 *', border: OutlineInputBorder())),
        const Divider(height: 28), const Text('전기 · 설비', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        option('배터리',hasBattery,(v)=>hasBattery=v,battery,'Ah'), option('태양광',hasSolar,(v)=>hasSolar=v,solar,'W'), option('인버터',hasInverter,(v)=>hasInverter=v,inverter,'W'), option('주행충전기',hasAlternator,(v)=>hasAlternator=v,alternator,'A'), option('청수',hasFresh,(v)=>hasFresh=v,fresh,'L'), option('오수',hasGrey,(v)=>hasGrey=v,grey,'L'),
        DropdownButtonFormField<String>(initialValue: toilet, decoration: const InputDecoration(labelText: '화장실 타입', border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'none',child:Text('없음')),DropdownMenuItem(value:'cassette',child:Text('카트리지')),DropdownMenuItem(value:'black',child:Text('블랙'))], onChanged:(v)=>ss(()=>toilet=v??'none')),
        if(toilet!='none') Padding(padding: const EdgeInsets.only(top:8), child:_num(toiletCap,'화장실 용량','L')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('한전충전 ${shore ? '있음' : '없음'}'), value: shore, onChanged:(v)=>ss(()=>shore=v)),
        TextField(controller:desc,maxLines:5,decoration:const InputDecoration(labelText:'기타 옵션 / 차량 설명',border:OutlineInputBorder())), const SizedBox(height:14),
        FilledButton.icon(onPressed:(){ if(title.text.trim().isEmpty||model.text.trim().isEmpty||region.text.trim().isEmpty||phone.text.trim().isEmpty){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('필수 항목을 입력해주세요.')));return;} Navigator.pop(ctx,true);},icon:const Icon(Icons.check),label:const Text('매물 등록')),
      ])));
    }));
    if(ok!=true)return; final uid=_db.auth.currentUser?.id; if(uid==null)return;
    try {
      await _db.from('vehicle_market_listings').insert({'owner_id':uid,'title':title.text.trim(),'manufacturer':maker.text.trim(),'model':model.text.trim(),'model_year':int.tryParse(year.text),'mileage_km':int.tryParse(mileage.text),'price_krw':int.tryParse(price.text),'region':region.text.trim(),'phone':phone.text.trim(),'description':desc.text.trim(),'battery_ah':hasBattery?int.tryParse(battery.text):null,'solar_w':hasSolar?int.tryParse(solar.text):null,'inverter_w':hasInverter?int.tryParse(inverter.text):null,'alternator_charger_a':hasAlternator?int.tryParse(alternator.text):null,'fresh_water_l':hasFresh?int.tryParse(fresh.text):null,'grey_water_l':hasGrey?int.tryParse(grey.text):null,'toilet_type':toilet,'toilet_capacity_l':toilet!='none'?int.tryParse(toiletCap.text):null,'shore_power':shore});
      if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('중고 캠핑카가 등록되었습니다.'))); await _load();
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('등록 실패: $e'))); }
  }

  String _spec(Map<String,dynamic>x){final a=<String>[];if(x['battery_ah']!=null)a.add('배터리 ${x['battery_ah']}Ah');if(x['solar_w']!=null)a.add('태양광 ${x['solar_w']}W');if(x['inverter_w']!=null)a.add('인버터 ${x['inverter_w']}W');if(x['alternator_charger_a']!=null)a.add('주행충전 ${x['alternator_charger_a']}A');if(x['fresh_water_l']!=null)a.add('청수 ${x['fresh_water_l']}L');if(x['grey_water_l']!=null)a.add('오수 ${x['grey_water_l']}L');final t='${x['toilet_type']}';a.add('화장실 ${t=='cassette'?'카트리지':t=='black'?'블랙':'없음'}${x['toilet_capacity_l']!=null?' ${x['toilet_capacity_l']}L':''}');a.add('한전충전 ${x['shore_power']==true?'있음':'없음'}');return a.join(' · ');}

  @override
  Widget build(BuildContext context) {
    final rows=_filtered;
    return Scaffold(
      appBar:AppBar(title:const Text('차량중고마켓')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,10,12,6),child:Row(children:[Expanded(child:SearchBar(controller:_search,hintText:'캠핑카, 모델명 검색',leading:const Icon(Icons.search),onChanged:(v)=>setState(()=>_query=v.trim()))),const SizedBox(width:8),IconButton.filledTonal(onPressed:_filters,icon:const Icon(Icons.tune),tooltip:'필터')])),
        Expanded(child:_loading ? const Center(child:CircularProgressIndicator()) : rows.isEmpty ? const Center(child:Text('조건에 맞는 중고 캠핑카가 없습니다.')) : RefreshIndicator(onRefresh:_load,child:ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
          final x=rows[i];
          return Card(margin:const EdgeInsets.fromLTRB(12,6,12,6),child:ListTile(
            leading:const CircleAvatar(child:Icon(Icons.directions_car)), title:Text('${x['title']}'), subtitle:Text('${x['manufacturer']} ${x['model']} · ${x['model_year']??'연식미상'}\n${x['region']} · ${x['mileage_km']??'-'}km'), trailing:Text(_money(x['price_krw']),style:const TextStyle(fontWeight:FontWeight.bold)),
            onTap:()=>showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('${x['title']}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('${x['manufacturer']} ${x['model']} · ${x['model_year']??'연식미상'}'),Text('주행거리: ${x['mileage_km']??'-'}km'),Text('판매지역: ${x['region']}'),Text('판매가격: ${_money(x['price_krw'])}'),const SizedBox(height:10),Text(_spec(x)),const SizedBox(height:10),Text('연락처: ${x['phone']}'),if('${x['description']??''}'.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('${x['description']}'))])))),
          ));
        })))
      ]),
      floatingActionButton:FloatingActionButton.extended(onPressed:_register,icon:const Icon(Icons.add),label:const Text('차량 등록')),
    );
  }
}
