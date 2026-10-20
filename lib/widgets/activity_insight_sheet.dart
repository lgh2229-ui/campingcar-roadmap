import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import 'activity_spot_review_sheet.dart';

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
      await _loadReviewCounts();
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
  final Map<String, int> _reviewCounts = {};

  String _spotKey(Map<String, dynamic> spot) {
    final external = (spot['content_id'] ?? spot['contentid'] ?? spot['id'] ?? '')
        .toString().trim().toLowerCase();
    if (external.isNotEmpty) {
      final value = 'external:' + external;
      return value.length > 400 ? value.substring(0, 400) : value;
    }
    final name = (spot['name'] ?? '').toString()
        .trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final address = (spot['address'] ?? '').toString()
        .trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final location = address.isNotEmpty ? address :
        (spot['lat'] ?? '').toString() + ',' + (spot['lon'] ?? '').toString();
    final value = name + '|' + location;
    return value.length > 400 ? value.substring(0, 400) : value;
  }

  Future<void> _loadReviewCounts() async {
    try {
      final rows = await Supabase.instance.client
          .from('activity_spot_reviews').select('spot_key')
          .eq('place_id', widget.place.id)
          .eq('activity', widget.activity);
      final counts = <String, int>{};
      for (final row in rows as List) {
        final key = (row['spot_key'] ?? '').toString();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (mounted) setState(() {
        _reviewCounts..clear()..addAll(counts);
      });
    } catch (_) {
      // Nearby tourist information remains available even if reviews fail.
    }
  }

  Future<void> _openSpotReviews(Map<String, dynamic> spot) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ActivitySpotReviewSheet(
        placeId: widget.place.id,
        activity: widget.activity,
        spotKey: _spotKey(spot),
        spotName: (spot['name'] ?? '주변 장소').toString(),
      ),
    );
    if (mounted) await _loadReviewCounts();
  }

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && ['https','http','tel'].contains(uri.scheme)) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열지 못했습니다.')));
      }
    }
  }
  Widget _heading(String text, {String? detail}) => Padding(
    padding:const EdgeInsets.only(top:20,bottom:10),
    child:Row(children:[
      Expanded(child:Text(text,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
      if(detail!=null)Text(detail,style:TextStyle(
        fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );

  Widget _tag(String title, {IconData? icon}) {
    final scheme=Theme.of(context).colorScheme;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
      decoration:BoxDecoration(
        color:scheme.surfaceContainerHighest.withValues(alpha:.55),
        borderRadius:BorderRadius.circular(9),
      ),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        if(icon!=null)...[Icon(icon,size:13,color:scheme.onSurfaceVariant),
          const SizedBox(width:4)],
        Text(title,style:TextStyle(fontSize:11,
          fontWeight:FontWeight.w600,color:scheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _detailRow(IconData icon,String label,String value) {
    final scheme=Theme.of(context).colorScheme;
    return Padding(padding:const EdgeInsets.only(top:6),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,size:15,color:scheme.onSurfaceVariant),
        const SizedBox(width:7),
        Expanded(child:Text('$label$value',
          style:TextStyle(fontSize:12.5,height:1.35,color:scheme.onSurface))),
      ]),
    );
  }

  Widget _summaryCard(Map<String,dynamic> data,int spotCount) {
    final scheme=Theme.of(context).colorScheme;
    final summary=(data['summary']??'').toString().trim();
    final ai=data['ai_generated']==true;
    return Container(
      width:double.infinity,
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        color:scheme.primaryContainer.withValues(alpha:.33),
        borderRadius:BorderRadius.circular(17),
        border:Border.all(color:scheme.primary.withValues(alpha:.12)),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(Icons.explore_outlined,color:scheme.primary,size:19),
          const SizedBox(width:8),
          const Expanded(child:Text('주변 한눈에 보기',
            style:TextStyle(fontSize:15,fontWeight:FontWeight.w800))),
          _tag('$spotCount곳 확인'),
        ]),
        const SizedBox(height:11),
        Text(summary.isEmpty?'확인된 주변 정보가 아직 없습니다.':summary,
          style:const TextStyle(fontSize:14,height:1.5)),
        if(spotCount>0)...[
          const SizedBox(height:9),
          Text(ai?'웹검색 및 공개자료를 바탕으로 정리했어요.'
            :'공개 지도와 관광자료를 바탕으로 정리했어요.',
            style:TextStyle(fontSize:11,color:scheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
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
    final scheme=Theme.of(context).colorScheme;
    final name=(spot['name']??'장소명 미확인').toString();
    final kind=(spot['kind']??widget.activity).toString();
    final description=(spot['description']??'').toString();
    final address=(spot['address']??'').toString();
    final phone=(spot['phone']??'').toString();
    final hours=(spot['opening_hours']??'').toString();
    final fee=(spot['fee']??'').toString();
    final website=(spot['website']??'').toString();
    final source=(spot['source_url']??'').toString();
    final lat=spot['lat'],lon=spot['lon'];
    final distance=spot['distance_m'];
    final meters=distance is num?distance.round():null;
    return Container(
      margin:const EdgeInsets.only(bottom:10),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:scheme.surface,
        border:Border.all(color:scheme.outlineVariant.withValues(alpha:.75)),
        borderRadius:BorderRadius.circular(16),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(name,style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        Wrap(spacing:6,runSpacing:6,children:[
          if(kind.isNotEmpty)_tag(kind,icon:Icons.category_outlined),
          if(meters!=null)_tag(meters>=1000?
            '${(meters/1000).toStringAsFixed(1)}km':'약 ${meters}m',
            icon:Icons.near_me_outlined),
        ]),
        if(description.isNotEmpty)Padding(
          padding:const EdgeInsets.only(top:10),
          child:Text(description,style:const TextStyle(fontSize:13.5,height:1.48))),
        if(address.isNotEmpty)_detailRow(Icons.place_outlined,'주소  ',address),
        if(hours.isNotEmpty)_detailRow(Icons.schedule_outlined,'운영  ',hours),
        if(fee.isNotEmpty)_detailRow(Icons.payments_outlined,'요금  ',fee),
        if(phone.isNotEmpty)_detailRow(Icons.call_outlined,'전화  ',phone),
        if((lat is num && lon is num)||phone.isNotEmpty||
           website.startsWith('https://')||source.startsWith('https://'))...[
          const SizedBox(height:10),
          Divider(color:scheme.outlineVariant.withValues(alpha:.6),height:1),
          const SizedBox(height:5),
          Wrap(spacing:2,runSpacing:0,children:[
            if(lat is num && lon is num)TextButton.icon(
              onPressed:()=>_open('https://www.google.com/maps/search/?api=1&query=$lat,$lon'),
              icon:const Icon(Icons.map_outlined,size:17),label:const Text('지도')),
            if(phone.isNotEmpty)TextButton.icon(
              onPressed:()=>_open('tel:$phone'),
              icon:const Icon(Icons.call_outlined,size:17),label:const Text('전화')),
            if(website.startsWith('https://'))TextButton.icon(
              onPressed:()=>_open(website),
              icon:const Icon(Icons.language_outlined,size:17),
              label:const Text('홈페이지')),
            if(source.startsWith('https://'))TextButton.icon(
              onPressed:()=>_open(source),
              icon:const Icon(Icons.open_in_new,size:17),label:const Text('출처')),
          ]),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openSpotReviews(spot),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('리뷰보기'),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openSpotReviews(spot),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, size: 17),
                  const SizedBox(width: 5),
                  Text('댓글 ' + (_reviewCounts[_spotKey(spot)] ?? 0).toString() + '개',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _providerCard(Map<String,dynamic> contact) {
    final name=(contact['name']??'업체/장소').toString();
    final phone=(contact['phone']??'').toString();
    final source=(contact['source_url']??'').toString();
    final scheme=Theme.of(context).colorScheme;
    return Container(
      padding:const EdgeInsets.symmetric(vertical:10,horizontal:12),
      margin:const EdgeInsets.only(bottom:8),
      decoration:BoxDecoration(
        color:scheme.surface,
        border:Border.all(color:scheme.outlineVariant),
        borderRadius:BorderRadius.circular(12),
      ),
      child:Row(children:[
        Icon(Icons.storefront_outlined,size:21,color:scheme.primary),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          if(phone.isNotEmpty)Text(phone,
            style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant)),
        ])),
        if(phone.isNotEmpty)IconButton(
          tooltip:'전화 걸기',onPressed:()=>_open('tel:$phone'),
          icon:const Icon(Icons.call_outlined)),
        if(source.startsWith('https://'))IconButton(
          tooltip:'정보 출처',onPressed:()=>_open(source),
          icon:const Icon(Icons.open_in_new)),
      ]),
    );
  }

  Widget _content(Map<String,dynamic> data) {
    final spots=_rows(data['spots']);
    final contacts=_rows(data['providers']);
    final sources=_rows(data['sources']).where(
      (x)=>(x['url']??'').toString().startsWith('https://')).toList();
    final photos=_rows(data['photos']);
    final suggested=_rows(data['suggested_places']);
    final tips=data['tips'] is List
        ? (data['tips'] as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList()
        : <String>[];
    final when=DateTime.tryParse((data['fetched_at']??'').toString())?.toLocal();
    final date=when==null?'':('${when.year}.${when.month.toString().padLeft(2,'0')}.${when.day.toString().padLeft(2,'0')}');
    final scheme=Theme.of(context).colorScheme;
    return ListView(
      padding:const EdgeInsets.fromLTRB(16,13,16,30),
      children:[
        // Keep technical provenance compact and visually subordinate.
        Wrap(spacing:6,runSpacing:6,children:[
          if(date.isNotEmpty)_tag('확인 $date',icon:Icons.event_available_outlined),
          _tag('반경 3km',icon:Icons.near_me_outlined),
          if(data['cached']==true)_tag('정보 보관 중',icon:Icons.bookmark_outline),
        ]),
        if(data['stale']==true)Padding(
          padding:const EdgeInsets.only(top:8),
          child:Text('저장된 기존 정보를 표시하고 있습니다.',
            style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant))),
        if(data['temporarily_unavailable']==true)Padding(
          padding:const EdgeInsets.only(top:8),
          child:Text('검색 서버 연결이 원활하지 않습니다. 기존 정보는 유지됩니다.',
            style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant))),
        if(data['research_status']=='not_confirmed')Padding(
          padding:const EdgeInsets.only(top:8),
          child:Text('위치가 검증된 정보가 아직 없습니다. 이용 불가를 뜻하지 않습니다.',
            style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant))),
        const SizedBox(height:13),
        _summaryCard(data,spots.length),

        _heading('주변 즐길 거리',detail:'${spots.length}곳'),
        if(spots.isEmpty)Container(
          padding:const EdgeInsets.symmetric(horizontal:14,vertical:16),
          decoration:BoxDecoration(
            color:scheme.surfaceContainerLow,
            borderRadius:BorderRadius.circular(13)),
          child:Row(children:[
            Icon(Icons.info_outline,color:scheme.onSurfaceVariant),
            const SizedBox(width:10),
            const Expanded(child:Text(
              '현재 확인된 장소가 없습니다. 실제 이용할 수 없다는 뜻은 아닙니다.',
              style:TextStyle(fontSize:13,height:1.4))),
          ]),
        ),
        ...spots.map(_spot),

        // Photos are shown only when licensed images are actually available.
        if(photos.isNotEmpty)...[
          _heading('주변 사진',detail:'${photos.length}장'),
          _photoGallery(photos),
        ],

        if(contacts.isNotEmpty)...[
          _heading(widget.activity=='낚시'?'낚시 관련 업체·연락처':'연락처가 있는 장소',
            detail:'${contacts.length}곳'),
          ...contacts.map(_providerCard),
          if(widget.activity=='낚시')Padding(
            padding:const EdgeInsets.only(bottom:6),
            child:Text('낚시용품점과 낚싯배 예약업체는 다릅니다. 출항·요금·예약을 확인하세요.',
              style:TextStyle(fontSize:11.5,color:scheme.onSurfaceVariant))),
        ],

        if(suggested.isNotEmpty)...[
          _heading('추가 확인 중',detail:'${suggested.length}건'),
          Padding(padding:const EdgeInsets.only(bottom:9),
            child:Text('웹에서 찾은 후보이며, 3km 이내 위치는 아직 검증되지 않았습니다.',
              style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant))),
          ...suggested.map((item)=>Container(
            margin:const EdgeInsets.only(bottom:6),
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
            decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(12),
              border:Border.all(color:scheme.outlineVariant)),
            child:Row(children:[
              const Icon(Icons.place_outlined,size:18),
              const SizedBox(width:8),
              Expanded(child:Text((item['name']??'장소 후보').toString(),
                style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
              if((item['source_url']??'').toString().startsWith('https://'))
                TextButton(onPressed:()=>_open(item['source_url'].toString()),
                  child:const Text('출처')),
            ]),
          )),
        ],

        if(sources.isNotEmpty)Padding(
          padding:const EdgeInsets.only(top:12),
          child:Container(
            decoration:BoxDecoration(
              border:Border.all(color:scheme.outlineVariant),
              borderRadius:BorderRadius.circular(13),
            ),
            child:ExpansionTile(
              tilePadding:const EdgeInsets.symmetric(horizontal:14),
              childrenPadding:const EdgeInsets.fromLTRB(8,0,8,8),
              leading:Icon(Icons.fact_check_outlined,color:scheme.primary),
              title:Text('정보 출처 ${sources.length}건',
                style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
              subtitle:const Text('눌러서 확인',style:TextStyle(fontSize:11)),
              children:sources.take(15).map((item)=>Align(
                alignment:Alignment.centerLeft,
                child:TextButton.icon(
                  onPressed:()=>_open(item['url'].toString()),
                  icon:const Icon(Icons.open_in_new,size:16),
                  label:Text((item['name']??'출처 열기').toString(),
                    maxLines:2,overflow:TextOverflow.ellipsis),
                ),
              )).toList(),
            ),
          ),
        ),

        Padding(
          padding:const EdgeInsets.only(top:16,bottom:8),
          child:SizedBox(width:double.infinity,
            child:OutlinedButton.icon(
              onPressed:_reportIssue,
              icon:const Icon(Icons.flag_outlined,size:19),
              label:const Text('주변 정보 오류·변경 신고'),
              style:OutlinedButton.styleFrom(
                padding:const EdgeInsets.symmetric(vertical:14),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),
            )),
        ),
        if(tips.isNotEmpty)ExpansionTile(
          tilePadding:EdgeInsets.zero,
          leading:Icon(Icons.info_outline,color:scheme.onSurfaceVariant,size:19),
          title:const Text('이용 안내·주의사항',
            style:TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
          children:tips.map((tip)=>Padding(
            padding:const EdgeInsets.only(bottom:9,left:8,right:8),
            child:Align(alignment:Alignment.centerLeft,
              child:Text('• $tip',
                style:const TextStyle(fontSize:12,height:1.35))))).toList(),
        ),
        Padding(padding:const EdgeInsets.only(top:8),
          child:Text('자료 출처 및 실제 운영·출입·요금은 방문 전 확인하세요. 저장된 정보의 재검색은 신고 후 관리자만 가능합니다.',
            style:TextStyle(fontSize:11,height:1.4,color:scheme.onSurfaceVariant))),
        Align(alignment:Alignment.centerLeft,child:TextButton(
          onPressed:()=>_open('https://www.openstreetmap.org/copyright'),
          child:const Text('OpenStreetMap 저작권',style:TextStyle(fontSize:11)),
        )),
      ],
    );
  }

  @override Widget build(BuildContext context) => SafeArea(top:false,
    child:SizedBox(height:MediaQuery.of(context).size.height*.87,
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(18,9,8,11),
          child:Row(children:[
            Container(
              padding:const EdgeInsets.all(8),
              decoration:BoxDecoration(
                color:Theme.of(context).colorScheme.primaryContainer.withValues(alpha:.5),
                borderRadius:BorderRadius.circular(12)),
              child:Icon(Icons.explore_outlined,size:23,
                color:Theme.of(context).colorScheme.primary)),
            const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(widget.activity,style:const TextStyle(
                fontSize:20,fontWeight:FontWeight.w800)),
              const SizedBox(height:2),
              Text(widget.place.name+' · 3km 주변',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:12,
                  color:Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            IconButton(tooltip:'저장된 정보 다시 보기',onPressed:_refresh,
              icon:const Icon(Icons.refresh_rounded)),
            IconButton(tooltip:'닫기',onPressed:()=>Navigator.pop(context),
              icon:const Icon(Icons.close_rounded)),
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
