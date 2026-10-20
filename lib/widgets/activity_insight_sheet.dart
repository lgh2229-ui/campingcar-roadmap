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

  Future<Map<String, dynamic>> _search() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'nearby-activity',
        body: {'place_id': widget.place.id, 'activity': widget.activity},
      );
      if (response.data is! Map) throw StateError('검색 결과 형식이 올바르지 않습니다.');
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) throw StateError(data['error'].toString());
      return data;
    } catch (e) {
      // Never expose raw HTTP exceptions or internal backend diagnostics to users.
      final raw = e.toString().toLowerCase();
      if (raw.contains('401') || raw.contains('jwt') || raw.contains('인증')) {
        throw StateError('로그인 시간이 만료됐습니다. 다시 로그인해 주세요.');
      }
      throw StateError('주변 검색 서버 연결이 원활하지 않습니다. 잠시 후 다시 시도해 주세요.');
    }
  }
  // Standard user reloads only the permanent cache. Only admins may
  // execute a paid AI refresh associated with a pending member report.
  void _refresh() => setState(() => result = _search());
  Future<void> _reportIssue() async {
    final controller=TextEditingController();
    final reason=await showDialog<String>(
      context:context,
      builder:(dialog)=>AlertDialog(
        title:const Text('주변 정보 오류 신고'),
        content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(widget.place.name+' · '+widget.activity),
          const SizedBox(height:10),
          TextField(controller:controller,maxLines:4,maxLength:500,
            decoration:const InputDecoration(
              hintText:'변경된 점이나 잘못된 정보를 구체적으로 알려주세요.',
              border:OutlineInputBorder())),
          const Text('신고된 내용은 관리자가 확인하며, 일반 회원은 AI 재검색을 실행할 수 없습니다.',
            style:TextStyle(fontSize:12)),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('취소')),
          FilledButton(onPressed:(){
            final value=controller.text.trim();
            if(value.length<5)return;
            Navigator.pop(dialog,value);
          },child:const Text('신고 제출'))
        ],
      ),
    );
    controller.dispose();
    if(reason==null||reason.length<5)return;
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('로그인이 필요합니다.')));
      return;
    }
    try{
      await Supabase.instance.client.from('place_activity_reports').insert({
        'place_id':widget.place.id,'activity':widget.activity,
        'reporter_id':user.id,'reason':reason,'status':'pending'
      });
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('신고가 접수됐습니다. 관리자 검토 후 필요할 때 AI로 재검색합니다.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('신고 저장에 실패했습니다. 다시 시도해주세요.')));
    }
  }
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
  Widget _photoGallery(List<Map<String,dynamic>> photos) {
    if(photos.isEmpty) return Padding(
      padding:const EdgeInsets.only(bottom:7),
      child:Text('저작권과 장소 연결이 확인된 사진은 아직 없습니다.',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    );
    return SizedBox(height:235,child:ListView.separated(
      scrollDirection:Axis.horizontal,
      itemCount:photos.length,
      separatorBuilder:(_,__)=>const SizedBox(width:10),
      itemBuilder:(context,index){
        final photo=photos[index],url=(photo['url']??'').toString();
        final source=(photo['source_url']??'').toString();
        final license=(photo['license']??'').toString();
        final artist=(photo['attribution']??'').toString();
        final name=(photo['name']??'산책·관광 사진').toString();
        return SizedBox(width:MediaQuery.of(context).size.width*.76,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            InkWell(onTap:(){
              showDialog<void>(context:context,builder:(dialog)=>Dialog(
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Image.network(url,fit:BoxFit.contain,
                    errorBuilder:(_,__,___)=>const Padding(padding:EdgeInsets.all(24),
                      child:Text('사진을 불러올 수 없습니다.'))),
                  Padding(padding:const EdgeInsets.all(12),child:Text(
                    '$name · $artist · $license',style:const TextStyle(fontSize:12))),
                  TextButton(onPressed:source.startsWith('https://')?()=>_open(source):null,
                    child:const Text('원본 사진·저작권 출처 열기')),
                  TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('닫기')),
                ]),
              ));
            },
              child:ClipRRect(borderRadius:BorderRadius.circular(13),
                child:SizedBox(height:170,width:double.infinity,
                  child:Image.network(url,fit:BoxFit.cover,
                    errorBuilder:(_,__,___)=>ColoredBox(
                      color:Theme.of(context).colorScheme.surfaceContainerHighest,
                      child:const Center(child:Icon(Icons.broken_image_outlined)))))),
            ),
            const SizedBox(height:5),
            Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
            Row(children:[
              Expanded(child:Text(artist+' · '+license,
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant))),
              IconButton(tooltip:'사진 출처',onPressed:source.startsWith('https://')?()=>_open(source):null,
                icon:const Icon(Icons.open_in_new,size:17),visualDensity:VisualDensity.compact),
            ]),
          ]));
      },
    ));
  }
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
    final sources = _rows(data['sources']);
    final photos = _rows(data['photos']);
    final suggested = _rows(data['suggested_places']);
    final tips = data['tips'] is List ? (data['tips'] as List).map((e) => e.toString()).toList() : <String>[];
    final ai = data['ai_generated'] == true;
    final when = DateTime.tryParse((data['fetched_at'] ?? '').toString())?.toLocal();
    return ListView(padding:const EdgeInsets.fromLTRB(16, 0, 16, 28),children: [
      if (when != null) Padding(padding:const EdgeInsets.only(top:9),child:Text(
        '검색 날짜: ' + when.year.toString() + '.' + when.month.toString()
        + '.' + when.day.toString() + ' · 관광기관·지역지도·공개 웹자료',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant))),
      if (data['stale'] == true) const Text('검색 서버가 일시적으로 느려 저장된 기존 정보를 보여드립니다.'),
      if (data['research_status'] == 'not_confirmed') const Text('추가 조사 완료 · 반경 3km 내 위치 확정 자료는 아직 없음'),
      if (data['cached'] == true) Text('저장된 정보 · 자동 만료 없음 · 재검색은 신고 후 관리자만 가능',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      if (data['temporarily_unavailable'] == true) const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('등록 정보는 유지됩니다. 인터넷 검색 서버가 정상화되면 다시 확인할 수 있습니다.')),

      _heading(ai ? 'AI 주변정보 요약' : '주변정보 요약'),
      Text((data['summary'] ?? '').toString(),style:const TextStyle(height:1.5)),
      if (!ai && spots.isNotEmpty) Text('확인된 지도·관광자료를 자동으로 정리한 내용입니다. 실시간 AI 웹검색은 서버 설정 시 사용됩니다.',
        style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      _heading('주변 사진 · 출처 확인된 자료'),
      _photoGallery(photos),
      if (suggested.isNotEmpty) _heading('추가 확인 중인 웹검색 후보 · 3km 거리 미확인'),
      if (suggested.isNotEmpty) const Padding(
        padding: EdgeInsets.only(bottom:8),
        child:Text('아래 장소는 웹에서 관련 정보가 발견됐지만 좌표가 확인되지 않았습니다. 확정된 3km 추천은 아닙니다.',
          style:TextStyle(fontSize:12)),
      ),
      ...suggested.map((item) => Card(
        elevation:0,
        child:Padding(padding:const EdgeInsets.all(12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((item['name']??'장소 후보').toString(),
              style:const TextStyle(fontWeight:FontWeight.w600)),
            if ((item['source_url']??'').toString().startsWith('https://'))
              Align(alignment:Alignment.centerLeft,child:TextButton.icon(
                onPressed:()=>_open(item['source_url'].toString()),
                icon:const Icon(Icons.open_in_new,size:17),
                label:const Text('해당 정보 출처 열기'),
              )),
          ])),
      )),
      _heading('3km 이내 관련 장소 · ' + spots.length.toString() + '곳'),
      if (spots.isEmpty) const Text('공개지도에서 확인되지 않았습니다. 실제 이용 불가를 의미하지 않습니다.'),
      ...spots.map(_spot),
      _heading(widget.activity == '낚시' ? '낚시 관련 연락처·업체' : '연락처가 등록된 장소'),
      if (contacts.isEmpty) const Text('확인된 연락처 정보가 없습니다. 업체 정보를 임의로 생성하지 않습니다.'),
      ...contacts.map(_spot),
      if (widget.activity == '낚시') const Text('선상낚시 업체/출항/요금은 별도 확인이 필요하며, 낚시용품점은 낚싯배 예약업체가 아닙니다.'),
      if (sources.isNotEmpty) _heading('정보 출처 · 눌러서 확인'),
      ...sources.where((item) => (item['url'] ?? '').toString().startsWith('https://'))
        .take(15).map((item) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _open(item['url'].toString()),
            icon: const Icon(Icons.open_in_new,size:16),
            label: Text((item['name'] ?? '출처 열기').toString(),maxLines:2,
              overflow:TextOverflow.ellipsis),
          ),
        )),
      Padding(padding:const EdgeInsets.symmetric(vertical:10),child:OutlinedButton.icon(
        onPressed:_reportIssue,
        icon:const Icon(Icons.flag_outlined),
        label:const Text('주변 정보 오류·변경 신고'),
      )),
      _heading('이용 안내·주의사항'),
      ...tips.map((tip) => Padding(padding:const EdgeInsets.only(bottom:6),child:Text('• '+tip))),
      const SizedBox(height:18),
      Text('장소별 정보 출처는 아래 링크에서 확인하세요. OpenStreetMap 지도자료 © OpenStreetMap contributors. 운영·출입·요금은 현장 재확인.',
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
            IconButton(tooltip:'저장된 정보 다시 보기',onPressed:_refresh,icon:const Icon(Icons.refresh)),
            IconButton(tooltip:'닫기',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
          ])),
        const Divider(height:1),
        Expanded(child:FutureBuilder<Map<String,dynamic>>(future:result,builder:(ctx,snapshot){
          if (snapshot.connectionState != ConnectionState.done) return const Center(
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              CircularProgressIndicator(),SizedBox(height:12),Text('3km 주변 정보를 검색 중입니다...')]));
          if (snapshot.hasError) return Center(child:Padding(padding:const EdgeInsets.all(24),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              const Text('주변 정보를 불러오지 못했습니다.\n잠시 후 다시 검색해주세요.',
                textAlign:TextAlign.center),
              const SizedBox(height:12),
              FilledButton(onPressed:_refresh,child:const Text('다시 검색'))])));
          return _content(snapshot.data!);
        })),
      ])));
}
