import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_home_screen.dart';
import '../models/place.dart';
import '../repositories/supabase_repository.dart';
class AdminManagementScreen extends StatefulWidget{const AdminManagementScreen({super.key});@override State<AdminManagementScreen> createState()=>_S();}
class _S extends State<AdminManagementScreen> with SingleTickerProviderStateMixin{
 final db=Supabase.instance.client;final memberSearch=TextEditingController();late final TabController tabs;List<Map<String,dynamic>> market=[],members=[],feedback=[],reports=[],reviewTasks=[];List<Place> places=[];bool loading=true;String memberQuery='';bool approvalCompleted=false,feedbackCompleted=false,reportCompleted=false;
 @override void initState(){super.initState();tabs=TabController(length:4,vsync:this);_load();}@override void dispose(){memberSearch.dispose();tabs.dispose();super.dispose();}
 Future<void> _load()async{setState(()=>loading=true);try{final a=await Future.wait([db.from('vehicle_market_listings').select().order('created_at',ascending:false),db.from('profiles').select().order('created_at',ascending:false),db.from('app_feedback').select().order('created_at',ascending:false),db.from('vehicle_market_reports').select().order('created_at',ascending:false),db.from('review_admin_tasks').select('*, reviews(author_id,body,status), places(name)').order('created_at',ascending:false),db.from('places').select().order('created_at',ascending:false)]);if(mounted)setState((){market=List<Map<String,dynamic>>.from(a[0]);members=List<Map<String,dynamic>>.from(a[1]);feedback=List<Map<String,dynamic>>.from(a[2]);reports=List<Map<String,dynamic>>.from(a[3]);reviewTasks=List<Map<String,dynamic>>.from(a[4]);places=List<Map<String,dynamic>>.from(a[5]).map(Place.fromJson).toList();});}finally{if(mounted)setState(()=>loading=false);}}
 String _userId(Map<String,dynamic>x)=>'${x['username']??x['user_id']??''}'.trim();
 String _nickname(Map<String,dynamic>x)=>'${x['nickname']??x['display_name']??''}'.trim();
 String _memberTitle(Map<String,dynamic>x){final a=_userId(x),b=_nickname(x);return a.isNotEmpty&&b.isNotEmpty?'$a · $b':a.isNotEmpty?a:b.isNotEmpty?b:'회원정보 없음';}
 String _name(dynamic id){for(final m in members){if('${m['id']}'=='$id')return _nickname(m).isEmpty?_userId(m):_nickname(m);}return'닉네임 없음';}
 String _nameById(dynamic id)=>_name(id);
 String _dt(dynamic v){final d=DateTime.tryParse('$v')?.toLocal();return d==null?'-':d.toString().substring(0,16);}
 List<Map<String,dynamic>> get _filteredMembers{final q=memberQuery.trim().toLowerCase();if(q.isEmpty)return members;return members.where((x)=>'${_userId(x)} ${_nickname(x)}'.toLowerCase().contains(q)).toList();}
 void msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> _reply(Map<String,dynamic>x)async{final c=TextEditingController(text:'${x['admin_reply']??''}');final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('${x['title']}'),content:TextField(controller:c,maxLines:6,decoration:const InputDecoration(labelText:'관리자 답변',border:OutlineInputBorder()),),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('답변 저장'))]));if(ok==true&&c.text.trim().isNotEmpty){await db.from('app_feedback').update({'admin_reply':c.text.trim(),'status':'answered','answered_at':DateTime.now().toIso8601String()}).eq('id',x['id']);await _load();}}
 Future<void> _member(Map<String,dynamic>x,String s)async{await db.from('profiles').update({'account_status':s}).eq('id',x['id']);await _load();}
 Future<void> _showMember(Map<String,dynamic>x)async{final f=<MapEntry<String,String>>[MapEntry('아이디',_userId(x)),MapEntry('닉네임',_nickname(x)),MapEntry('휴대폰','${x['phone']??''}'),MapEntry('휴대폰 인증',x['phone_verified']==true?'완료':'미인증'),MapEntry('회원상태','${x['account_status']??'active'}'),MapEntry('권한','${x['role']??'user'}'),MapEntry('차량상태','${x['vehicle_status']??''}'),MapEntry('차량명/모델','${x['vehicle_name']??''}'),MapEntry('차량높이',x['vehicle_height_mm']==null?'':'${(x['vehicle_height_mm']as num)/1000} m'),MapEntry('위생설비','${x['sanitation_type']??''}'),MapEntry('가입일',_dt(x['created_at'])),MapEntry('마지막접속일자 및 시간',_dt(x['last_seen_at']))];await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(c)=>SafeArea(child:SizedBox(height:MediaQuery.of(c).size.height*.78,child:Column(children:[Padding(padding:const EdgeInsets.all(16),child:Text(_memberTitle(x),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),Expanded(child:ListView(children:f.map((e)=>ListTile(title:Text(e.key),subtitle:Text(e.value))).toList()))]))));}
 Widget _photos(dynamic raw){final p=List<String>.from(raw??const[]);if(p.isEmpty)return const SizedBox.shrink();return SizedBox(height:74,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:p.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i)=>ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(p[i],width:92,height:74,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:92,child:Icon(Icons.broken_image_outlined))))));}
 Widget _approvalTab(){final pending=places.where((p)=>p.approvalStatus=='pending').toList(),done=places.where((p)=>p.approvalStatus!='pending').toList(),r=approvalCompleted?done:pending;return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text('처리대기 (${pending.length})')),ButtonSegment(value:true,label:Text('처리완료 (${done.length})'))],selected:{approvalCompleted},onSelectionChanged:(v)=>setState(()=>approvalCompleted=v.first))),Expanded(child:_approvalList(r,approvalCompleted))]);}
 Widget _approvalList(List<Place> r,bool done)=>r.isEmpty?Center(child:Text(done?'처리 완료 내역이 없습니다.':'승인 대기 장소가 없습니다.')):ListView.builder(itemCount:r.length,itemBuilder:(_,i){final p=r[i];return ListTile(leading:Icon(done?Icons.check_circle:Icons.hourglass_top),title:Text(p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'),'')),subtitle:Text('${p.address}\n등록자: ${p.ownerNickname.trim().isEmpty?'닉네임 없음':p.ownerNickname} · ${_dt(p.createdAt)}'),isThreeLine:true,trailing:done?Text(p.approvalStatus=='approved'?'승인완료':'반려완료'):const Icon(Icons.chevron_right),onTap:done?null:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>AdminPlaceReviewScreen(place:p,data:SupabaseRepository(db)))).then((_)=>_load()));});
 Widget _feedbackTab(){final r=feedback.where((x)=>(x['status']=='answered')==feedbackCompleted).toList();return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text('처리대기 (${feedback.where((x)=>x['status']!='answered').length})')),ButtonSegment(value:true,label:Text('처리완료 (${feedback.where((x)=>x['status']=='answered').length})'))],selected:{feedbackCompleted},onSelectionChanged:(v)=>setState(()=>feedbackCompleted=v.first))),Expanded(child:r.isEmpty?Center(child:Text(feedbackCompleted?'처리 완료된 의견이 없습니다.':'처리 대기 중인 의견이 없습니다.')):ListView.builder(itemCount:r.length,itemBuilder:(_,i){final x=r[i];return ListTile(title:Text('${x['title']}'),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x['body']}\n작성자: ${_name(x['author_id'])} · 요청: ${_dt(x['created_at'])}\n${x['status']=='answered'?'처리완료':'처리대기'}'),_photos(x['photo_urls'])]),trailing:Text(x['status']=='answered'?'완료':'대기'),onTap:()=>_reply(x));}))]);}
 Future<void> _completeReviewTask(Map<String,dynamic>x)async{
  final c=TextEditingController(text:'${x['admin_reply']??''}');
  final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
    title:const Text('검증 요청 처리완료'),
    content:TextField(controller:c,maxLines:5,decoration:const InputDecoration(labelText:'사용자에게 보낼 답변',hintText:'처리 결과를 입력해주세요.',border:OutlineInputBorder())),
    actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('답변 후 처리완료'))]));
  if(ok!=true)return;
  if(c.text.trim().isEmpty){msg('답변 내용을 입력해주세요.');return;}
  try{
    await db.from('review_admin_tasks').update({'admin_reply':c.text.trim(),'handled':true,'handled_by':db.auth.currentUser!.id,'handled_at':DateTime.now().toIso8601String()}).eq('id',x['id']);
    await _load();
  }catch(e){msg('처리완료 저장에 실패했습니다: $e');}
 }
 Future<void> _completeReport(Map<String,dynamic>x)async{
  final c=TextEditingController(text:'${x['admin_reply']??''}');
  final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
    title:const Text('신고 처리완료'),
    content:TextField(controller:c,maxLines:5,decoration:const InputDecoration(labelText:'신고자에게 보낼 답변',hintText:'처리 결과를 입력해주세요.',border:OutlineInputBorder())),
    actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('답변 후 처리완료'))]));
  if(ok!=true)return;
  if(c.text.trim().isEmpty){msg('답변 내용을 입력해주세요.');return;}
  try{await db.from('vehicle_market_reports').update({'admin_reply':c.text.trim(),'status':'resolved','handled_by':db.auth.currentUser!.id,'handled_at':DateTime.now().toIso8601String()}).eq('id',x['id']);await _load();}catch(e){msg('신고 처리완료 저장에 실패했습니다: $e');}
 }
 Widget _reportTab(){
  bool marketDone(Map<String,dynamic>x)=>['completed','handled','resolved','done'].contains('${x['status']??''}'.toLowerCase());
  final marketRows=reports.where((x)=>marketDone(x)==reportCompleted).map((x)=>({...x,'_kind':'market'})).toList();
  final reviewRows=reviewTasks.where((x)=>(x['handled']==true)==reportCompleted).map((x)=>({...x,'_kind':'review'})).toList();
  final r=<Map<String,dynamic>>[...reviewRows,...marketRows]..sort((a,b)=>'${b['created_at']}'.compareTo('${a['created_at']}'));
  final pending=reports.where((x)=>!marketDone(x)).length+reviewTasks.where((x)=>x['handled']!=true).length;
  final completed=reports.where(marketDone).length+reviewTasks.where((x)=>x['handled']==true).length;
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text('처리대기 ($pending)')),ButtonSegment(value:true,label:Text('처리완료 ($completed)'))],selected:{reportCompleted},onSelectionChanged:(v)=>setState(()=>reportCompleted=v.first))),
   Expanded(child:r.isEmpty?Center(child:Text(reportCompleted?'처리 완료된 항목이 없습니다.':'처리 대기 중인 항목이 없습니다.')):ListView.builder(itemCount:r.length,itemBuilder:(_,i){
    final x=r[i],isReview=x['_kind']=='review';
    if(isReview){
      final review=Map<String,dynamic>.from(x['reviews']??{}),place=Map<String,dynamic>.from(x['places']??{});
      final done=x['handled']==true;
      return ListTile(leading:Icon(done?Icons.check_circle:Icons.rate_review_outlined),title:Text('장소 검증 · ${place['name']??'장소'}'),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x['reason']} · ${review['body']??''}\n작성자: ${_name(review['author_id'])} · 요청: ${_dt(x['created_at'])}${done&&'${x['admin_reply']??''}'.isNotEmpty?'\n답변: ${x['admin_reply']}':''}'),_photos(review['photo_urls'])]),trailing:done?const Text('처리완료'):FilledButton.tonal(onPressed:()=>_completeReviewTask(x),child:const Text('처리완료')));
    }
    final done=marketDone(x);
    return ListTile(leading:Icon(done?Icons.check_circle:Icons.report_problem_outlined),title:Text('매물 ${x['listing_id']}'),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x['reason']}\n신고자: ${_name(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}${done&&'${x['admin_reply']??''}'.isNotEmpty?'\n답변: ${x['admin_reply']}':''}'),_photos(x['photo_urls'])]),trailing:done?const Text('처리완료'):FilledButton.tonal(onPressed:()=>_completeReport(x),child:const Text('처리완료')));
   }))
  ]);
 }
 Widget _memberTab(){final r=_filteredMembers;return Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(controller:memberSearch,onChanged:(v)=>setState(()=>memberQuery=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'아이디 · 닉네임 통합검색',border:OutlineInputBorder()))),Expanded(child:ListView.builder(itemCount:r.length,itemBuilder:(_,i){final x=r[i];return ListTile(title:Text(_memberTitle(x)),subtitle:Text('상태: ${x['account_status']??'active'}'),onTap:()=>_showMember(x),trailing:PopupMenuButton<String>(onSelected:(v)=>_member(x,v),itemBuilder:(_)=>const[PopupMenuItem(value:'active',child:Text('정상 복구')),PopupMenuItem(value:'suspended',child:Text('자격정지')),PopupMenuItem(value:'withdrawn',child:Text('탈퇴 처리'))]));}))]);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('관리자 통합관리'),bottom:TabBar(controller:tabs,isScrollable:true,tabs:const[Tab(text:'장소승인'),Tab(text:'회원'),Tab(text:'의견'),Tab(text:'신고')])),body:loading?const Center(child:CircularProgressIndicator()):TabBarView(controller:tabs,children:[_approvalTab(),_memberTab(),_feedbackTab(),_reportTab()]));
}
