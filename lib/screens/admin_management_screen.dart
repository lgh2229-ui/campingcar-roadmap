import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});
  @override State<AdminManagementScreen> createState() => _S();
}

class _S extends State<AdminManagementScreen> with SingleTickerProviderStateMixin {
  final db = Supabase.instance.client;
  final memberSearch = TextEditingController();
  late final TabController tabs;
  List<Map<String, dynamic>> market = [], members = [], feedback = [], reports = [];
  bool loading = true;
  String memberQuery = '';

  @override void initState() { super.initState(); tabs = TabController(length: 4, vsync: this); _load(); }
  @override void dispose() { memberSearch.dispose(); tabs.dispose(); super.dispose(); }

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

  String _userId(Map<String,dynamic> x) => '${x['username'] ?? x['user_id'] ?? ''}'.trim();
  String _nickname(Map<String,dynamic> x) => '${x['nickname'] ?? x['display_name'] ?? ''}'.trim();
  String _memberTitle(Map<String,dynamic> x) {
    final id = _userId(x), nick = _nickname(x);
    if (id.isNotEmpty && nick.isNotEmpty) return '$id · $nick';
    if (id.isNotEmpty) return id;
    if (nick.isNotEmpty) return nick;
    return '회원정보 없음';
  }

  List<Map<String,dynamic>> get _filteredMembers {
    final q = memberQuery.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members.where((x) {
      final hay = [
        _userId(x), _nickname(x), '${x['phone'] ?? ''}', '${x['vehicle_name'] ?? ''}', '${x['role'] ?? ''}', '${x['account_status'] ?? ''}'
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> _reply(Map<String,dynamic> x) async { final c=TextEditingController(text:'${x['admin_reply']??''}'); final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('${x['title']}'),content:TextField(controller:c,maxLines:6,decoration:const InputDecoration(labelText:'관리자 답변',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('답변 저장'))])); if(ok==true&&c.text.trim().isNotEmpty){await db.from('app_feedback').update({'admin_reply':c.text.trim(),'status':'answered','answered_at':DateTime.now().toIso8601String()}).eq('id',x['id']);await _load();} }
  Future<void> _member(Map<String,dynamic> x,String status) async { await db.from('profiles').update({'account_status':status}).eq('id',x['id']); msg(status=='suspended'?'자격정지 처리했습니다.':status=='withdrawn'?'탈퇴 처리했습니다.':'정상 회원으로 복구했습니다.'); await _load(); }
  Future<void> _deleteMarket(Map<String,dynamic> x) async { await db.from('vehicle_market_listings').delete().eq('id',x['id']); await _load(); }
  Future<void> _editMarket(Map<String,dynamic> x) async { final t=TextEditingController(text:'${x['title']}'),p=TextEditingController(text:'${x['price_krw']??''}'),d=TextEditingController(text:'${x['description']??''}'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('매물 관리자 수정'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'제목')),TextField(controller:p,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'가격')),TextField(controller:d,maxLines:4,decoration:const InputDecoration(labelText:'설명'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('저장'))])); if(ok==true){await db.from('vehicle_market_listings').update({'title':t.text.trim(),'price_krw':int.tryParse(p.text),'description':d.text.trim()}).eq('id',x['id']);await _load();} }

  Future<void> _showMember(Map<String,dynamic> x) async {
    final fields = <MapEntry<String,String>>[
      MapEntry('아이디', _userId(x)), MapEntry('닉네임', _nickname(x)), MapEntry('휴대폰', '${x['phone'] ?? ''}'),
      MapEntry('휴대폰 인증', x['phone_verified'] == true ? '완료' : '미인증'), MapEntry('회원상태', '${x['account_status'] ?? 'active'}'),
      MapEntry('권한', '${x['role'] ?? 'user'}'), MapEntry('차량상태', '${x['vehicle_status'] ?? ''}'), MapEntry('차량명/모델', '${x['vehicle_name'] ?? ''}'),
      MapEntry('차량높이', x['vehicle_height_mm'] == null ? '' : '${(x['vehicle_height_mm'] as num) / 1000} m'), MapEntry('위생설비', '${x['sanitation_type'] ?? ''}'),
      MapEntry('가입일', '${x['created_at'] ?? ''}'),
    ];
    await showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => SafeArea(child: SizedBox(
      height: MediaQuery.of(ctx).size.height * .78,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20,4,20,12), child: Text(_memberTitle(x), style: const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        const Divider(height:1),
        Expanded(child: ListView(children: fields.where((e)=>e.value.trim().isNotEmpty).map((e)=>ListTile(title:Text(e.key),subtitle:Text(e.value))).toList())),
      ]),
    ))));
  }

  Widget _memberTab() {
    final rows = _filteredMembers;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        controller: memberSearch,
        onChanged: (v) => setState(() => memberQuery = v),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '아이디 · 닉네임 · 휴대폰 · 차량 통합검색', suffixIcon: memberQuery.isEmpty ? null : IconButton(onPressed:(){memberSearch.clear();setState(()=>memberQuery='');},icon:const Icon(Icons.close)), border: const OutlineInputBorder()),
      )),
      Expanded(child: rows.isEmpty ? const Center(child: Text('검색 결과가 없습니다.')) : ListView.builder(itemCount:rows.length,itemBuilder:(_,i){final x=rows[i];return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)), title:Text(_memberTitle(x)), subtitle:Text('상태: ${x['account_status']??'active'}'),
        onTap:()=>_showMember(x), trailing:PopupMenuButton<String>(onSelected:(v)=>_member(x,v),itemBuilder:(_)=>const [PopupMenuItem(value:'active',child:Text('정상 복구')),PopupMenuItem(value:'suspended',child:Text('자격정지')),PopupMenuItem(value:'withdrawn',child:Text('탈퇴 처리'))]));})),
    ]);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('관리자 통합관리'), bottom: TabBar(controller: tabs, isScrollable: true, tabs: const [Tab(text:'중고매물'),Tab(text:'회원'),Tab(text:'의견'),Tab(text:'신고')])),
    body: loading ? const Center(child:CircularProgressIndicator()) : TabBarView(controller:tabs,children:[
      ListView.builder(itemCount:market.length,itemBuilder:(_,i){final x=market[i];return ListTile(title:Text('${x['title']}'),subtitle:Text(x['status']=='sold'?'판매완료':'판매중'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_editMarket(x);if(v=='delete')_deleteMarket(x);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('수정')),PopupMenuItem(value:'delete',child:Text('삭제'))]));}),
      _memberTab(),
      ListView.builder(itemCount:feedback.length,itemBuilder:(_,i){final x=feedback[i];return ListTile(title:Text('${x['title']}'),subtitle:Text('${x['body']}\n${x['status']=='answered'?'답변완료':'답변대기'}'),isThreeLine:true,onTap:()=>_reply(x));}),
      ListView.builder(itemCount:reports.length,itemBuilder:(_,i){final x=reports[i];return ListTile(leading:const Icon(Icons.report),title:Text('매물 ${x['listing_id']}'),subtitle:Text('${x['reason']}'),trailing:Text('${x['status']}'));}),
    ]),
  );
}
