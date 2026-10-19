import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';

class ActivityInsightSheet extends StatefulWidget {
  const ActivityInsightSheet({super.key, required this.place, required this.activity});
  final Place place;
  final String activity;
  @override State<ActivityInsightSheet> createState() => _ActivityInsightSheetState();
}

class _ActivityInsightSheetState extends State<ActivityInsightSheet> {
  late Future<Map<String, dynamic>> result;
  @override void initState() { super.initState(); result = _search(); }

  Future<Map<String, dynamic>> _search({bool refresh = false}) async {
    final response = await Supabase.instance.client.functions.invoke('nearby-activity',
      body: {'place_id': widget.place.id, 'activity': widget.activity,
        if (refresh) 'force_refresh': true});
    if (response.data is! Map) throw StateError('검색 결과를 읽지 못했습니다.');
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw StateError(data['error'].toString());
    return data;
  }
  void _refresh() => setState(() => result = _search(refresh: true));
  List<Map<String, dynamic>> _rows(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && ['https','http','tel'].contains(uri.scheme)) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열지 못했습니다.')));
      }
    }
  }
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 9),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
  Widget _spot(Map<String, dynamic> spot) {
    final name = (spot['name'] ?? '').toString();
    final kind = (spot['kind'] ?? '').toString();
    final description = (spot['description'] ?? '').toString();
    final address = (spot['address'] ?? '').toString();
    final phone = (spot['phone'] ?? '').toString();
    final hours = (spot['opening_hours'] ?? '').toString();
    final fee = (spot['fee'] ?? '').toString();
    final website = (spot['website'] ?? '').toString();
    final source = (spot['source_url'] ?? '').toString();
    final lat = spot['lat'], lon = spot['lon'];
    final dist = spot['distance_m'] is num ? (spot['distance_m'] as num).round() : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(kind + ' · 약 ' + dist.toString() + 'm',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (description.isNotEmpty) Padding(padding:const EdgeInsets.only(top:6),child:Text(description)),
          if (address.isNotEmpty) Text('등록 주소: ' + address,style:const TextStyle(fontSize:12)),
          if (hours.isNotEmpty) Text('공개지도 운영시간: ' + hours),
          if (fee.isNotEmpty) Text('공개지도 요금 표기: ' + fee),
          if (phone.isNotEmpty) Text('연락처: ' + phone),
          Wrap(spacing: 4, children: [
            if (lat is num && lon is num) TextButton.icon(
              onPressed: () => _open('https://www.google.com/maps/search/?api=1&query='
                + lat.toString() + ',' + lon.toString()),
              icon: const Icon(Icons.map_outlined,size:18),label:const Text('지도')),
            if (phone.isNotEmpty) TextButton.icon(
              onPressed: () => _open('tel:' + phone),
              icon: const Icon(Icons.call_outlined,size:18),label:const Text('전화')),
            if (website.startsWith('http')) TextButton(
              onPressed: () => _open(website),child:const Text('홈페이지')),
            if (source.startsWith('https://')) TextButton(
              onPressed: () => _open(source),child:const Text('출처')),
          ]),
        ])));
  }
  Widget _content(Map<String, dynamic> data) {
    final spots = _rows(data['spots']);
    final contacts = _rows(data['providers']);
    final tips = data['tips'] is List ? (data['tips'] as List).map((e) => e.toString()).toList() : <String>[];
    final ai = data['ai_generated'] == true;
    final when = DateTime.tryParse((data['fetched_at'] ?? '').toString())?.toLocal();
    return ListView(padding:const EdgeInsets.fromLTRB(16, 0, 16, 28),children: [
      if (when != null) Padding(padding:const EdgeInsets.only(top:9),child:Text(
        '검색 날짜: ' + when.year.toString() + '.' + when.month.toString()
        + '.' + when.day.toString() + ' · OpenStreetMap 공개지도',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant))),
      if (data['stale'] == true) const Text('최신 검색이 실패해 이전 정보를 표시 중입니다.'),
      _heading(ai ? 'AI 주변정보 요약' : '주변정보 요약'),
      Text((data['summary'] ?? '').toString(),style:const TextStyle(height:1.5)),
      if (!ai) Text('공개지도 검색결과 자동 요약입니다. AI 문장 생성은 서버 키 설정 후 제공됩니다.',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      _heading('3km 이내 관련 장소 · ' + spots.length.toString() + '곳'),
      if (spots.isEmpty) const Text('공개지도에서 확인되지 않았습니다. 실제 이용 불가를 의미하지 않습니다.'),
      ...spots.map(_spot),
      _heading(widget.activity == '낚시' ? '낚시 관련 연락처·업체' : '연락처가 등록된 장소'),
      if (contacts.isEmpty) const Text('확인된 연락처 정보가 없습니다. 업체 정보를 임의로 생성하지 않습니다.'),
      ...contacts.map(_spot),
      if (widget.activity == '낚시') const Text('선상낚시 업체/출항/요금은 별도 확인이 필요하며, 낚시용품점은 낚싯배 예약업체가 아닙니다.'),
      _heading('이용 안내·주의사항'),
      ...tips.map((tip) => Padding(padding:const EdgeInsets.only(bottom:6),child:Text('• '+tip))),
      const SizedBox(height:18),
      Text('지도 데이터 © OpenStreetMap contributors · 운영/허가/요금 정보는 방문 전 재확인',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      TextButton(onPressed:()=>_open('https://www.openstreetmap.org/copyright'),
        child:const Text('OpenStreetMap 저작권 안내')),
    ]);
  }
  @override Widget build(BuildContext context) => SafeArea(top:false,
    child:SizedBox(height:MediaQuery.of(context).size.height*.87,
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,8,8,6),
          child:Row(children:[
            const Icon(Icons.explore_outlined), const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(widget.activity,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              Text(widget.place.name+' · 반경 3km',
                style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            IconButton(tooltip:'새로 검색',onPressed:_refresh,icon:const Icon(Icons.refresh)),
            IconButton(tooltip:'닫기',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
          ])),
        const Divider(height:1),
        Expanded(child:FutureBuilder<Map<String,dynamic>>(future:result,builder:(ctx,snapshot){
          if (snapshot.connectionState != ConnectionState.done) return const Center(
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              CircularProgressIndicator(),SizedBox(height:12),Text('3km 주변 정보를 검색 중입니다...')]));
          if (snapshot.hasError) return Center(child:Padding(padding:const EdgeInsets.all(24),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text('검색에 실패했습니다.\n'+snapshot.error.toString(),textAlign:TextAlign.center),
              const SizedBox(height:12),
              FilledButton(onPressed:_refresh,child:const Text('다시 검색'))])));
          return _content(snapshot.data!);
        })),
      ])));
}
