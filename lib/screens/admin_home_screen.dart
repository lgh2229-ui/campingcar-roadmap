import 'dart:async';
import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../repositories/app_data_repository.dart';
import '../repositories/auth_repository.dart';
import 'admin_management_screen.dart';
import 'admin_screen.dart';
import '../repositories/local_repository.dart';
import 'home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key,required this.user,required this.auth,required this.data,required this.onUserChanged,required this.onLogout,this.focusPlaceId});
  final String? focusPlaceId; final AppUser user; final AuthRepository auth; final AppDataRepository data; final ValueChanged<AppUser> onUserChanged; final Future<void> Function() onLogout;
  @override State<AdminHomeScreen> createState()=>_AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool busy=false; int pendingCount=0, foodPendingCount=0, reportCount=0, feedbackCount=0, marketReportCount=0, mapRefreshSignal=0;
  StreamSubscription<Map<String,dynamic>>? _pushSub;
  Timer? _refreshTimer;
  @override void initState(){super.initState();_refreshCounts();_pushSub=PushNotificationService.instance.events.listen((_){_refreshCounts();});_refreshTimer=Timer.periodic(const Duration(seconds:20),(_)=>_refreshCounts());}
  @override void dispose(){_pushSub?.cancel();_refreshTimer?.cancel();super.dispose();}
  void _msg(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  String _dt(DateTime? d)=>d==null?'-':d.toLocal().toString().substring(0,16);
  String _owner(Place p)=>p.ownerNickname.trim().isEmpty?'닉네임 없음':p.ownerNickname.trim();
  Future<void> _refreshCounts() async {try{final db=Supabase.instance.client;final a=await Future.wait([widget.data.pendingPlaces(),widget.data.adminReviewTasks(),db.from('app_feedback').select('id').neq('status','answered'),db.from('vehicle_market_reports').select('id').neq('status','resolved'),db.from('food_recommendations').select('id').eq('status','pending')]);if(mounted)setState((){pendingCount=(a[0] as List).length;reportCount=(a[1] as List).length;feedbackCount=(a[2] as List).length;marketReportCount=(a[3] as List).length;foodPendingCount=(a[4] as List).length;});}catch(_){} }
  Widget _badge(Widget child,int count)=>Stack(clipBehavior:Clip.none,children:[child,if(count>0)Positioned(right:-7,top:-8,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(12)),constraints:const BoxConstraints(minWidth:20),child:Text(count>99?'99+':'$count',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold))))]);

  @override Widget build(BuildContext context)=>Stack(children:[
    HomeScreen(user:widget.user,auth:widget.auth,data:widget.data,onUserChanged:widget.onUserChanged,onLogout:widget.onLogout,refreshSignal:mapRefreshSignal,focusPlaceId:widget.focusPlaceId),
    Positioned(top:MediaQuery.of(context).padding.top+12,right:12,child:SafeArea(child:
      _badge(FloatingActionButton(heroTag:'adminManage',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AdminManagementScreen())).then((_){if(mounted)setState(()=>mapRefreshSignal++);_refreshCounts();}),child:const Icon(Icons.admin_panel_settings_outlined)),pendingCount+foodPendingCount+reportCount+feedbackCount+marketReportCount)
    )),
  ]);
}

class AdminPlaceReviewScreen extends StatefulWidget {const AdminPlaceReviewScreen({super.key,required this.place,required this.data});final Place place;final AppDataRepository data;@override State<AdminPlaceReviewScreen> createState()=>_AdminPlaceReviewScreenState();}
class _AdminPlaceReviewScreenState extends State<AdminPlaceReviewScreen>{bool saving=false;Place? refreshedPlace;
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_refreshReview();});}
  Future<void> _refreshReview()async{
    try{
      final db=Supabase.instance.client;
      final row=await db.from('places_view').select().eq('id',widget.place.id).maybeSingle();
      if(row==null||!mounted)return;
      final p=Place.fromJson(Map<String,dynamic>.from(row));
      final pics=await db.from('place_photos').select('public_url').eq('place_id',p.id);
      p.photoUrls=<String>{...p.photoUrls,...pics.map((a)=>(a['public_url']??'').toString()).where((url)=>url.isNotEmpty)}.toList();
      if(mounted)setState(()=>refreshedPlace=p);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('요청 장소 조회 실패: $e')));}
  }

  Future<void> _openPlaceEditor()async{
    final db=Supabase.instance.client;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>AdminScreen(
      user:AppUser(userId:'administrator',phone:'',nickname:'관리자',role:'admin',authId:db.auth.currentUser?.id??''),
      auth:AuthRepository(LocalRepository(),client:db),data:widget.data,
      initialEditPlaceId:widget.place.id,onLogout:()async{},
    )));
    if(mounted)await _refreshReview();
  }

  Future<void> _approve() async {
    final p=refreshedPlace??widget.place;
    if(p.approvalStatus!='pending'||saving)return;
    final ok=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('장소 등록 승인 확인'),
      content:Text('「'+p.name+'」\n지도·사진·주소·시설을 직접 확인하고 승인하시겠습니까?'
        +(p.note.contains('임시 위치')||p.photoUrls.isEmpty
          ? '\n\n주의: 임시 좌표 또는 사진 누락 항목이 있습니다.' : '')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('취소')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('승인')),
      ],
    ));
    if(ok!=true||!mounted)return;
    setState(()=>saving=true);
    try{
      final db=Supabase.instance.client;
      final changed=await db.from('places').update({
        'approval_status':'approved',
        'approved_at':DateTime.now().toUtc().toIso8601String(),
        'approved_by':db.auth.currentUser!.id,
      }).eq('id',widget.place.id).eq('approval_status','pending').select('id');
      if(changed.isEmpty)throw StateError('이미 처리된 요청입니다.');
      if(!mounted)return;
      Navigator.pop(context,true);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content:Text('승인에 실패했습니다: $e')));
    }finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> _reject()async{if((refreshedPlace??widget.place).approvalStatus!='pending'||saving)return;final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('장소 등록 반려'),content:Text((refreshedPlace??widget.place).name+'\n이 등록 요청을 반려할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('반려'))]));if(ok!=true)return;setState(()=>saving=true);try{final db=Supabase.instance.client;final changed=await db.from('places').update({'approval_status':'rejected','approved_at':null,'approved_by':db.auth.currentUser!.id}).eq('id',widget.place.id).eq('approval_status','pending').select('id');if(changed.isEmpty)throw StateError('이미 처리된 요청입니다.');if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('반려했습니다.')));Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('반려에 실패했습니다: $e')));}finally{if(mounted)setState(()=>saving=false);}}
  @override Widget build(BuildContext context){final p=refreshedPlace??widget.place;final point=LatLng(p.latitude,p.longitude);return Scaffold(appBar:AppBar(title:const Text('등록 장소 검토 · 수정')),body:SafeArea(bottom:true,child:Column(children:[Expanded(flex:5,child:FlutterMap(key:ValueKey(p.id+':'+p.latitude.toString()+':'+p.longitude.toString()),options:MapOptions(initialCenter:point,initialZoom:17),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'kr.co.campingcarroadmap.app'),MarkerLayer(markers:[Marker(point:point,width:70,height:70,alignment:Alignment.topCenter,child:const Icon(Icons.location_pin,size:58,color:Colors.red))])])),Expanded(flex:4,child:ListView(padding:const EdgeInsets.all(18),children:[Text(p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'),''),style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:6),if(p.address.isNotEmpty)Text(p.address),Text('등록자: ${p.ownerNickname.trim().isEmpty?'닉네임 없음':p.ownerNickname}'),Text('요청일시: ${p.createdAt==null?'-':p.createdAt!.toLocal().toString().substring(0,16)}'),const SizedBox(height:6),Text('서비스: ${p.services.join(' · ')}'),if(p.prices.isNotEmpty)...p.prices.entries.map((e)=>Text('${e.key}: ${e.value}')),if(p.hours.isNotEmpty)Text('운영시간: ${p.hours}'),if(p.reservation.isNotEmpty)Text('예약: ${p.reservation}'),if(p.maxHeightMm!=null)Text('진입 최대 높이: ${(p.maxHeightMm!/1000).toStringAsFixed(2)}m'),if(p.phone.isNotEmpty)Text('문의연락처: ${p.phone}'),if(p.note.isNotEmpty)Text('이용방법/주의사항: ${p.note}'),if(p.note.contains('임시 위치')||p.note.contains('승인 전 확인'))const Padding(padding:EdgeInsets.symmetric(vertical:9),child:Text('주의: 등록자가 임시 좌표 또는 현장 미확인 정보를 표시했습니다. 지도와 장소를 수정한 후 승인해주세요.',style:TextStyle(fontWeight:FontWeight.w700,color:Colors.deepOrange))),if(p.photoUrls.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:9),child:Text('첨부 사진 없음 · 「직접 수정」에서 현장 사진을 추가할 수 있습니다.')),if(p.photoUrls.isNotEmpty)...[const SizedBox(height:12),SizedBox(height:150,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:p.photoUrls.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i)=>ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(p.photoUrls[i],width:210,height:150,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:210,child:Center(child:Icon(Icons.broken_image_outlined)))))))],const SizedBox(height:18)])),Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:Column(mainAxisSize:MainAxisSize.min,children:[SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:saving?null:_openPlaceEditor,icon:const Icon(Icons.edit_outlined),label:const Text('지도·시설·주소·사진 직접 수정'))),if(p.approvalStatus=='pending')...[const SizedBox(height:8),Row(children:[Expanded(child:OutlinedButton(onPressed:saving?null:_reject,child:const Text('반려'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:saving?null:_approve,icon:const Icon(Icons.check),label:const Text('승인')))])]]))])));}
}
