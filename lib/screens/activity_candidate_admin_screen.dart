import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin verification step. A nearby OSM POI does not prove legal access.
class ActivityCandidateAdminScreen extends StatefulWidget {
  const ActivityCandidateAdminScreen({super.key});
  @override State<ActivityCandidateAdminScreen> createState() => _ActivityCandidateAdminScreenState();
}

class _ActivityCandidateAdminScreenState extends State<ActivityCandidateAdminScreen> {
  final db = Supabase.instance.client;
  bool running = false, stopRequested = false, loading = false;
  int scanned = 0, total = 0;
  String status = '';
  List<Map<String, dynamic>> rows = [];

  @override void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    setState(() => loading = true);
    try {
      final data = await db.from('place_activity_candidates')
        .select('place_id,activity,spot_count,example_spot,source_url,status,places(name,address,services)')
        .eq('status', 'pending').order('updated_at', ascending: false).limit(500);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) _message('후보 목록을 불러오지 못했습니다: ' + e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> _runAll() async {
    if(running)return;
    setState(() { running = true; stopRequested = false; scanned=0; total=0; status='조사 시작 중...'; });
    try {
      var offset=0;
      while(mounted && !stopRequested) {
        final response=await db.functions.invoke('discover-nearby-activities',
          body:{'offset':offset});
        if(response.data is! Map)throw StateError('검색 결과 형식 오류');
        final result=Map<String,dynamic>.from(response.data as Map);
        if(result['error']!=null)throw StateError(result['error'].toString());
        final next=(result['next_offset'] as num?)?.toInt()??offset;
        if(next==offset)break;
        offset=next;
        if(!mounted)break;
        setState(() {
          scanned=offset;
          total=(result['total'] as num?)?.toInt()??0;
          status='승인 장소 조사 중 · '+scanned.toString()+'/'+total.toString();
        });
        if(result['has_more']!=true)break;
        await Future<void>.delayed(const Duration(milliseconds:1100));
      }
      if(mounted) {
        setState(()=>status=stopRequested?'조사 일시중지':'조사 완료 · 검토할 후보를 확인하세요.');
        await _reload();
      }
    }catch(e) {
      if(mounted) {
        setState(()=>status='조사 중단: '+e.toString());
        _message(status);
        await _reload();
      }
    }finally{
      if(mounted)setState(()=>running=false);
    }
  }

  Future<void> _decide(Map<String,dynamic> candidate, bool approve) async {
    final id=candidate['place_id'].toString();
    final activity=candidate['activity'].toString();
    try {
      if(approve) {
        final existing=await db.from('places').select('services').eq('id',id).single();
        final services=List<String>.from(existing['services']??const <String>[]);
        if(!services.contains(activity)) {
          await db.from('places').update({'services':[...services,activity]}).eq('id',id);
        }
      }
      await db.from('place_activity_candidates')
        .update({'status':approve?'approved':'rejected','confidence':approve?'reviewed':'unreviewed'})
        .eq('place_id',id).eq('activity',activity);
      await _reload();
      if(mounted)_message(approve?'승인 후 장소에 활동 태그를 반영했습니다.':'추천 활동을 제외했습니다.');
    }catch(e){
      if(mounted)_message('적용 실패: '+e.toString());
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('주변 관광·레저 자동 조사')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('등록 장소 중심 3km 이내 공개지도 자료를 조사합니다.',
          style:TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:5),
        const Text('낚시·해루질 등의 법적 허용 여부는 자동으로 단정하지 않습니다. 관리자 승인 전에는 장소 정보에 자동 공개되지 않습니다.',
          style:TextStyle(fontSize:12)),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:FilledButton.icon(
            onPressed:running?null:_runAll,
            icon:const Icon(Icons.travel_explore_outlined),
            label:Text(running?'조사 중...':'전체 등록 장소 조사'))),
          if(running)TextButton(
            onPressed:()=>setState(()=>stopRequested=true),
            child:const Text('중지')),
        ]),
        if(total>0)Padding(padding:const EdgeInsets.only(top:9),
          child:LinearProgressIndicator(value:(scanned/total).clamp(0.0,1.0))),
        if(status.isNotEmpty)Padding(padding:const EdgeInsets.only(top:7),
          child:Text(status,style:const TextStyle(fontSize:12))),
      ])),
      const Divider(height:1),
      Padding(padding:const EdgeInsets.fromLTRB(16,11,8,8),child:Row(children:[
        Expanded(child:Text('관리자 검토 대기 '+rows.length.toString()+'건',
          style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
        IconButton(tooltip:'새로고침',onPressed:_reload,icon:const Icon(Icons.refresh)),
      ])),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):
        rows.isEmpty?const Center(child:Text('아직 확인할 관광·레저 후보가 없습니다.')):
        ListView.separated(
          itemCount:rows.length,
          separatorBuilder:(_,__)=>const Divider(height:1),
          itemBuilder:(context,i){
            final x=rows[i],place=x['places'];
            final p=place is Map?Map<String,dynamic>.from(place):<String,dynamic>{};
            final url=x['source_url'].toString();
            return Padding(padding:const EdgeInsets.fromLTRB(14,9,14,9),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((p['name']??'장소').toString()+' · '+x['activity'].toString(),
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                const SizedBox(height:3),
                Text('3km 내 POI '+x['spot_count'].toString()+'곳 · 예: '+x['example_spot'].toString(),
                  style:const TextStyle(fontSize:12)),
                Wrap(spacing:5,children:[
                  TextButton(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),
                    child:const Text('근거 지도 열기')),
                  TextButton.icon(onPressed:()=>_decide(x,false),
                    icon:const Icon(Icons.close,size:16),label:const Text('제외')),
                  FilledButton.tonalIcon(onPressed:()=>_decide(x,true),
                    icon:const Icon(Icons.check,size:16),label:const Text('확인 후 반영')),
                ]),
              ]));
          },
        )),
    ]),
  );
}
