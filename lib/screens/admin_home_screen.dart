import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/admin_review_task.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../repositories/app_data_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_repository.dart';
import 'admin_management_screen.dart';
import 'home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key,required this.user,required this.auth,required this.data,required this.onUserChanged,required this.onLogout});
  final AppUser user; final AuthRepository auth; final AppDataRepository data; final ValueChanged<AppUser> onUserChanged; final Future<void> Function() onLogout;
  @override State<AdminHomeScreen> createState()=>_AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool busy=false; int pendingCount=0, reportCount=0;
  @override void initState(){super.initState();_refreshCounts();}
  void _msg(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  String _dt(DateTime? d)=>d==null?'-':d.toLocal().toString().substring(0,16);
  String _owner(Place p)=>p.ownerNickname.trim().isEmpty?'닉네임 없음':p.ownerNickname.trim();
  Future<void> _refreshCounts() async {try{final a=await Future.wait([widget.data.pendingPlaces(),widget.data.adminReviewTasks()]);if(mounted)setState((){pendingCount=(a[0] as List).length;reportCount=(a[1] as List).length;});}catch(_){} }
  Widget _badge(Widget child,int count)=>Stack(clipBehavior:Clip.none,children:[child,if(count>0)Positioned(right:-7,top:-8,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(12)),constraints:const BoxConstraints(minWidth:20),child:Text(count>99?'99+':'$count',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold))))]);

  Future<void> _openApprovals() async {
    setState(()=>busy=true); List<Place> all=[];
    try{all=await widget.data.places();}catch(e){_msg('승인 목록을 불러오지 못했습니다: $e');}finally{if(mounted)setState(()=>busy=false);}
    if(!mounted)return;
    bool completed=false;
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setS){
      final rows=completed?all.where((p)=>p.approvalStatus!='pending').toList():all.where((p)=>p.approvalStatus=='pending').toList();
      return SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.78,child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(18,4,18,8),child:Row(children:[const Expanded(child:Text('장소 승인 목록',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),Chip(label:Text('${rows.length}건'))])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('처리대기')),ButtonSegment(value:true,label:Text('처리완료'))],selected:{completed},onSelectionChanged:(v)=>setS(()=>completed=v.first))),
        const Divider(),Expanded(child:rows.isEmpty?Center(child:Text(completed?'처리 완료 내역이 없습니다.':'승인 대기 장소가 없습니다.')):ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final p=rows[i];return ListTile(leading:Icon(p.approvalStatus=='approved'?Icons.check_circle:p.approvalStatus=='rejected'?Icons.cancel:Icons.hourglass_top),title:Text(p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'),'')),subtitle:Text('${p.address}\n등록자: ${_owner(p)} · 요청: ${_dt(p.createdAt)}\n${p.services.join(' · ')}'),isThreeLine:true,trailing:completed?Text(p.approvalStatus=='approved'?'승인완료':'반려완료'):const Icon(Icons.chevron_right),onTap:completed?null:(){Navigator.pop(ctx);Navigator.of(context).push(MaterialPageRoute(builder:(_)=>AdminPlaceReviewScreen(place:p,data:widget.data))).then((_){_refreshCounts();setState((){});});});})),
      ])));
    })); await _refreshCounts();
  }

  Future<void> _openReports() async {
    setState(()=>busy=true); List<AdminReviewTask> all=[];
    try{if(widget.data is SupabaseRepository){all=await (widget.data as SupabaseRepository).adminReviewTasks(includeHandled:true);}else{all=await widget.data.adminReviewTasks();}}catch(e){_msg('신고 목록을 불러오지 못했습니다: $e');}finally{if(mounted)setState(()=>busy=false);}
    if(!mounted)return; bool completed=false;
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setS){
      final rows=all.where((t)=>t.handled==completed).toList();
      return SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(18,4,18,8),child:Row(children:[const Expanded(child:Text('신고 목록',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),Chip(label:Text('${rows.length}건'))])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('처리대기')),ButtonSegment(value:true,label:Text('처리완료'))],selected:{completed},onSelectionChanged:(v)=>setS(()=>completed=v.first))),
        const Divider(),Expanded(child:rows.isEmpty?Center(child:Text(completed?'처리 완료 신고가 없습니다.':'처리할 신고가 없습니다.')):ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final t=rows[i];return ListTile(leading:Icon(t.handled?Icons.check_circle:Icons.report_problem_outlined),title:Text(t.reason),subtitle:Text('장소 ${t.placeId}\n요청: ${_dt(t.createdAt)}'),isThreeLine:true,trailing:t.handled?const Text('처리완료'):FilledButton.tonal(onPressed:()async{await widget.data.completeAdminReviewTask(t.id);all=all.map((x)=>x.id==t.id?AdminReviewTask(id:x.id,reviewId:x.reviewId,placeId:x.placeId,reason:x.reason,handled:true,createdAt:x.createdAt):x).toList();setS((){});await _refreshCounts();},child:const Text('확인 완료')));}))
      ])));
    })); await _refreshCounts();
  }

  @override Widget build(BuildContext context)=>Stack(children:[
    HomeScreen(user:widget.user,auth:widget.auth,data:widget.data,onUserChanged:widget.onUserChanged,onLogout:widget.onLogout),
    Positioned(top:MediaQuery.of(context).padding.top+12,right:12,child:SafeArea(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
      FloatingActionButton.small(heroTag:'adminManage',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AdminManagementScreen())).then((_){_refreshCounts();}),child:const Icon(Icons.manage_accounts)),const SizedBox(height:8),
      _badge(FloatingActionButton.extended(heroTag:'adminApprovalList',onPressed:busy?null:_openApprovals,icon:const Icon(Icons.fact_check_outlined),label:const Text('승인목록')),pendingCount),const SizedBox(height:8),
      _badge(FloatingActionButton.extended(heroTag:'adminReportList',onPressed:busy?null:_openReports,icon:const Icon(Icons.report_problem_outlined),label:const Text('신고목록')),reportCount),
    ]))),
  ]);
}

class AdminPlaceReviewScreen extends StatefulWidget {const AdminPlaceReviewScreen({super.key,required this.place,required this.data});final Place place;final AppDataRepository data;@override State<AdminPlaceReviewScreen> createState()=>_AdminPlaceReviewScreenState();}
class _AdminPlaceReviewScreenState extends State<AdminPlaceReviewScreen>{bool saving=false;
  Future<void> _approve()async{setState(()=>saving=true);try{await widget.data.approvePlace(widget.place.id);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('승인했습니다. 일반회원 지도에 공개됩니다.')));Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('승인에 실패했습니다: $e')));}finally{if(mounted)setState(()=>saving=false);}}
  Future<void> _reject()async{final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('장소 등록 반려'),content:Text('${widget.place.name}\n이 등록 요청을 반려할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('반려'))]));if(ok!=true)return;setState(()=>saving=true);try{await widget.data.rejectPlace(widget.place.id);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('반려했습니다.')));Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('반려에 실패했습니다: $e')));}finally{if(mounted)setState(()=>saving=false);}}
  @override Widget build(BuildContext context){final p=widget.place;final point=LatLng(p.latitude,p.longitude);return Scaffold(appBar:AppBar(title:const Text('등록 장소 확인')),body:Column(children:[Expanded(flex:5,child:FlutterMap(options:MapOptions(initialCenter:point,initialZoom:17),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'kr.co.campingcarroadmap.app'),MarkerLayer(markers:[Marker(point:point,width:70,height:70,alignment:Alignment.topCenter,child:const Icon(Icons.location_pin,size:58,color:Colors.red))])])),Expanded(flex:4,child:ListView(padding:const EdgeInsets.all(18),children:[Text(p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'),''),style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:6),if(p.address.isNotEmpty)Text(p.address),Text('등록자: ${p.ownerNickname.trim().isEmpty?'닉네임 없음':p.ownerNickname}'),Text('요청일시: ${p.createdAt==null?'-':p.createdAt!.toLocal().toString().substring(0,16)}'),const SizedBox(height:6),Text('서비스: ${p.services.join(' · ')}'),if(p.prices.isNotEmpty)...p.prices.entries.map((e)=>Text('${e.key}: ${e.value}')),if(p.hours.isNotEmpty)Text('운영시간: ${p.hours}'),if(p.reservation.isNotEmpty)Text('예약: ${p.reservation}'),if(p.maxHeightMm!=null)Text('진입 최대 높이: ${(p.maxHeightMm!/1000).toStringAsFixed(2)}m'),if(p.phone.isNotEmpty)Text('문의연락처: ${p.phone}'),if(p.note.isNotEmpty)Text('이용방법/주의사항: ${p.note}'),if(p.photoUrls.isNotEmpty)...[const SizedBox(height:12),SizedBox(height:150,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:p.photoUrls.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i)=>ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(p.photoUrls[i],width:210,height:150,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:210,child:Center(child:Icon(Icons.broken_image_outlined)))))))],const SizedBox(height:18),Row(children:[Expanded(child:OutlinedButton(onPressed:saving?null:_reject,child:const Text('반려'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:saving?null:_approve,icon:const Icon(Icons.check),label:const Text('승인')))])]))]));}
}
