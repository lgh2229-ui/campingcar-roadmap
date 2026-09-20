import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});
  @override State<AdminManagementScreen> createState() => _S();
}

class _S extends State<AdminManagementScreen> with SingleTickerProviderStateMixin {
  final db = Supabase.instance.client;
  late final TabController tabs;
  List<Map<String, dynamic>> market = [], members = [], feedback = [], reports = [];
  bool loading = true;

  @override void initState() { super.initState(); tabs = TabController(length: 4, vsync: this); _load(); }
  @override void dispose() { tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final a = await Future.wait([
        db.from('vehicle_market_listings').select().order('created_at', ascending: false),
        db.from('profiles').select().order('created_at', ascending: false),
        db.from('app_feedback').select().order('created_at', ascending: false),
        db.from('vehicle_market_reports').select().order('created_at', ascending: false),
      ]);
      if (mounted) setState(() { market = List<Map<String,dynamic>>.from(a[0]); members = List<Map<String,dynamic>>.from(a[1]); feedback = List<Map<String,dynamic>>.from(a[2]); reports = List<Map<String,dynamic>>.from(a[3]); });
    } finally { if (mounted) setState(() => loading = false); }
  }

  void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> _reply(Map<String,dynamic> x) async { final c=TextEditingController(text:'${x['admin_reply']??''}'); final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('${x['title']}'),content:TextField(controller:c,maxLines:6,decoration:const InputDecoration(labelText:'관리자 답변',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('답변 저장'))])); if(ok==true&&c.text.trim().isNotEmpty){await db.from('app_feedback').update({'admin_reply':c.text.trim(),'status':'answered','answered_at':DateTime.now().toIso8601String()}).eq('id',x['id']);await _load();} }
  Future<void> _member(Map<String,dynamic> x,String status) async { await db.from('profiles').update({'account_status':status}).eq('id',x['id']); msg(status=='suspended'?'자격정지 처리했습니다.':status=='withdrawn'?'탈퇴 처리했습니다.':'정상 회원으로 복구했습니다.'); await _load(); }
  Future<void> _deleteMarket(Map<String,dynamic> x) async { await db.from('vehicle_market_listings').delete().eq('id',x['id']); await _load(); }
  Future<void> _editMarket(Map<String,dynamic> x) async { final t=TextEditingController(text:'${x['title']}'),p=TextEditingController(text:'${x['price_krw']??''}'),d=TextEditingController(text:'${x['description']??''}'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('매물 관리자 수정'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'제목')),TextField(controller:p,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'가격')),TextField(controller:d,maxLines:4,decoration:const InputDecoration(labelText:'설명'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('저장'))])); if(ok==true){await db.from('vehicle_market_listings').update({'title':t.text.trim(),'price_krw':int.tryParse(p.text),'description':d.text.trim()}).eq('id',x['id']);await _load();} }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('관리자 통합관리'), bottom: TabBar(controller: tabs, isScrollable: true, tabs: const [Tab(text:'중고매물'),Tab(text:'회원'),Tab(text:'의견'),Tab(text:'신고')])),
    body: loading ? const Center(child:CircularProgressIndicator()) : TabBarView(controller:tabs,children:[
      ListView.builder(itemCount:market.length,itemBuilder:(_,i){final x=market[i];return ListTile(title:Text('${x['title']}'),subtitle:Text(x['status']=='sold'?'판매완료':'판매중'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_editMarket(x);if(v=='delete')_deleteMarket(x);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('수정')),PopupMenuItem(value:'delete',child:Text('삭제'))]));}),
      ListView.builder(itemCount:members.length,itemBuilder:(_,i){final x=members[i];return ListTile(title:Text('${x['display_name']??x['user_id']??x['id']}'),subtitle:Text('상태: ${x['account_status']??'active'}'),trailing:PopupMenuButton<String>(onSelected:(v)=>_member(x,v),itemBuilder:(_)=>const [PopupMenuItem(value:'active',child:Text('정상 복구')),PopupMenuItem(value:'suspended',child:Text('자격정지')),PopupMenuItem(value:'withdrawn',child:Text('탈퇴 처리'))]));}),
      ListView.builder(itemCount:feedback.length,itemBuilder:(_,i){final x=feedback[i];return ListTile(title:Text('${x['title']}'),subtitle:Text('${x['body']}\n${x['status']=='answered'?'답변완료':'답변대기'}'),isThreeLine:true,onTap:()=>_reply(x));}),
      ListView.builder(itemCount:reports.length,itemBuilder:(_,i){final x=reports[i];return ListTile(leading:const Icon(Icons.report),title:Text('매물 ${x['listing_id']}'),subtitle:Text('${x['reason']}'),trailing:Text('${x['status']}'));}),
    ]),
  );
}
