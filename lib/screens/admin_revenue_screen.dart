import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// AdMob revenue dashboard. Revenue is never fabricated or estimated locally.
class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});
  @override State<AdminRevenueScreen> createState()=>_AdminRevenueScreenState();
}
class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  final db=Supabase.instance.client;
  bool loading=false;
  String status='AdMob 계정 인증이 필요합니다.';
  Map<String,dynamic>? report;
  @override void initState(){super.initState();refresh();}
  Future<void> connect() async {
    try {
      final response=await db.functions.invoke('admob-oauth',body:{});
      final data=response.data;
      final link=data is Map?data['url']?.toString():null;
      if(link==null || link.isEmpty)throw Exception(data is Map?data['message']:'인증 URL이 없습니다.');
      if(!await launchUrl(Uri.parse(link),mode:LaunchMode.externalApplication))throw Exception('브라우저를 열 수 없습니다.');
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('AdMob 연결 실패: $e')));
    }
  }
  Future<void> refresh() async {
    if(loading)return;
    setState(()=>loading=true);
    try {
      final response=await db.functions.invoke('admob-revenue');
      if(!mounted)return;
      final data=response.data;
      if(data is Map && data['connected']==true && data['report'] is Map) {
        setState((){report=Map<String,dynamic>.from(data['report']);status='';});
      } else {
        setState((){report=null;status=data is Map?(data['message']??'Google 계정 연결이 필요합니다.').toString():'Google 계정 연결이 필요합니다.';});
      }
    } catch(_) {
      if(mounted)setState((){report=null;status='수익 조회 서버 또는 Google 계정 인증이 아직 준비되지 않았습니다.';});
    } finally {if(mounted)setState(()=>loading=false);}
  }
  Widget tile(String label,dynamic value)=>Card(child:Padding(padding:const EdgeInsets.all(16),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:Theme.of(context).textTheme.labelMedium),
      const SizedBox(height:8),
      Text(value==null?'—':value.toString(),style:Theme.of(context).textTheme.titleLarge),
    ])));
  @override Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('광고수익 · AdMob'),actions:[
      IconButton(onPressed:loading?null:refresh,icon:const Icon(Icons.refresh))]),
    body:RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('게시자 ID: pub-4393751265116181'),
      const SizedBox(height:12),
      if(loading)const LinearProgressIndicator(),
      if(report==null)Card(child:Padding(padding:const EdgeInsets.all(18),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.lock_outline,size:28),
          const SizedBox(height:10),
          Text(status,style:Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height:8),
          const Text('Google OAuth 인증이 완료되면 실제 AdMob 보고서 수치만 표시합니다. 현재 수익은 0원이 아니라 미연결 상태입니다.'),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:connect,icon:const Icon(Icons.link),label:const Text('Google AdMob 계정 연결')),
          const Text('브라우저에서 Google 동의를 마친 뒤 앱으로 돌아와 새로고침하세요.'),
        ]))),
      if(report!=null)...[
        tile('오늘 예상 수익',report!['today']),
        tile('어제 예상 수익',report!['yesterday']),
        tile('최근 7일',report!['last7Days']),
        tile('이번 달',report!['thisMonth']),
        tile('지난달',report!['lastMonth']),
        tile('노출 수',report!['impressions']),
        tile('클릭 수',report!['clicks']),
        tile('eCPM',report!['ecpm']),
      ],
      const SizedBox(height:12),
      const Text('AdMob 예상 수익은 최종 지급액과 다를 수 있습니다.'),
    ])));
}
