import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only authenticated administrators can load reports or force an AI search.
class ActivityReportAdminScreen extends StatefulWidget {
  const ActivityReportAdminScreen({super.key});

  @override
  State<ActivityReportAdminScreen> createState() => _ActivityReportAdminScreenState();
}

class _ActivityReportAdminScreenState extends State<ActivityReportAdminScreen> {
  final db = Supabase.instance.client;
  List<Map<String,dynamic>> reports = [];
  Map<String,dynamic>? budget;
  bool loading = true;
  final Set<String> busy = {};

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if(mounted) setState(() => loading=true);
    try {
      final replies=await Future.wait<dynamic>([
        db.from('place_activity_reports')
          .select('id,place_id,activity,reason,reporter_id,created_at,status,places(name,address)')
          .eq('status','pending').order('created_at',ascending:false).limit(150),
        db.rpc('camping_ai_budget_status'),
      ]);
      if(mounted) setState(() {
        reports=List<Map<String,dynamic>>.from(replies[0] as List);
        if(replies[1] is Map) {
          budget=Map<String,dynamic>.from(replies[1] as Map);
        }
      });
    } catch(e) {
      _notify('신고 및 예산정보를 불러오지 못했습니다.');
    } finally {
      if(mounted) setState(() => loading=false);
    }
  }

  void _notify(String message) {
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(message)));
  }

  Future<void> _decide(Map<String,dynamic> report, bool research) async {
    final id=report['id'].toString();
    if(busy.contains(id))return;
    final activity=report['activity'].toString();
    if(research) {
      final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('AI 정보 재검색'),
        content:Text('사용자 신고를 확인하고 "$activity"의 반경 3km 정보를 AI로 다시 검색하시겠습니까?\n\n검색 비용은 월 30,000원 예산에서 차감됩니다. 기존 정보는 검색 성공 전까지 유지됩니다.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('AI 재검색')),
        ],
      ));
      if(yes!=true)return;
    }
    setState(()=>busy.add(id));
    try {
      if(research){
        final r=await db.functions.invoke('nearby-activity',body:{
          'place_id':report['place_id'],
          'activity':activity,
          'report_id':id,
          'force_refresh':true
        });
        if(r.data is! Map)throw StateError('서버 응답이 올바르지 않습니다.');
        final data=Map<String,dynamic>.from(r.data as Map);
        if(data['error']!=null)throw StateError(data['error'].toString());
        if(data['warning']!=null)_notify(data['warning'].toString());
        else _notify('AI 검색 결과가 저장되고 해당 신고가 처리됐습니다.');
      } else {
        await db.from('place_activity_reports').update({
          'status':'rejected',
          'admin_id':db.auth.currentUser!.id,
          'resolved_at':DateTime.now().toUtc().toIso8601String(),
        }).eq('id',id).eq('status','pending');
        _notify('신고를 반려했습니다. 기존 정보는 유지됩니다.');
      }
      await _load();
    } catch(e) {
      _notify('요청 실패: '+e.toString().replaceFirst('Exception: ',''));
    } finally {
      if(mounted)setState(()=>busy.remove(id));
    }
  }

  @override Widget build(BuildContext context) {
    final limit=(budget?['monthly_budget_krw'] as num?)?.toInt()??30000;
    final spent=(budget?['spent_krw'] as num?)?.toInt()??0;
    return Scaffold(
      appBar:AppBar(title:const Text('관광·레저 사용자 신고 / AI 재검색'),
        actions:[IconButton(onPressed:_load,tooltip:'새로고침',icon:const Icon(Icons.refresh))]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(15,12,15,8),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('이번 달 AI 예산 · ${budget?['month_kst']??''}',
              style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:6),
            Text('누적 추정 사용액 ${spent.toString()}원 / ${limit.toString()}원',
              style:const TextStyle(fontSize:14)),
            const SizedBox(height:6),
            LinearProgressIndicator(value:limit==0?1:(spent/limit).clamp(0.0,1.0)),
            const SizedBox(height:8),
            const Text('저장한 데이터는 자동 만료되지 않습니다. 사용자 신고를 확인한 관리자만 재검색할 수 있습니다.',
              style:TextStyle(fontSize:12)),
          ],
        )),
        const Divider(),
        Expanded(child:loading?const Center(child:CircularProgressIndicator()):
          reports.isEmpty?const Center(child:Text('검토 대기 중인 관광·레저 신고가 없습니다.')):
          ListView.separated(
            itemCount:reports.length,
            separatorBuilder:(_,__)=>const Divider(height:1),
            itemBuilder:(ctx,i) {
              final report=reports[i];
              final place=report['places'] is Map
                ? Map<String,dynamic>.from(report['places'] as Map)
                : <String,dynamic>{};
              final id=report['id'].toString(), working=busy.contains(id);
              return Padding(padding:const EdgeInsets.all(14),child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${place['name']??'장소'} · ${report['activity']??''}',
                    style:const TextStyle(fontWeight:FontWeight.w700)),
                  const SizedBox(height:4),
                  Text(report['reason'].toString()),
                  const SizedBox(height:6),
                  Text('신고일 ${report['created_at']??''}',
                    style:const TextStyle(fontSize:12)),
                  Wrap(spacing:7,children:[
                    OutlinedButton(onPressed:working?null:()=>_decide(report,false),
                      child:const Text('신고 반려')),
                    FilledButton.icon(
                      onPressed:working?null:()=>_decide(report,true),
                      icon:working?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):
                        const Icon(Icons.auto_awesome,size:18),
                      label:Text(working?'처리 중':'관리자 AI 재검색'),
                    ),
                  ]),
                ]));
            },
          )),
      ]),
    );
  }
}
