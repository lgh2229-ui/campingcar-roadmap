from pathlib import Path

# Repository/model support is applied late in CI so UI and data layer stay in sync.
p=Path('lib/repositories/local_repository.dart'); s=p.read_text(encoding='utf-8')
if 'Future<void> deletePlace(String placeId)' not in s:
    a='  @override\n  Future<List<Place>> pendingPlaces() async'
    s=s.replace(a,"  @override\n  Future<void> deletePlace(String placeId) async { final list=await _allPlaces(); list.removeWhere((e)=>e.id==placeId); await savePlaces(list); }\n\n"+a)
p.write_text(s,encoding='utf-8')

p=Path('lib/repositories/supabase_repository.dart'); s=p.read_text(encoding='utf-8')
old="    for (final place in places) {\n      place.photoUrls = byPlace[place.id] ?? place.photoUrls;"
new="    final ownerIds=places.map((e)=>e.ownerId).where((e)=>e.isNotEmpty).toSet().toList(); final names=<String,String>{}; if(ownerIds.isNotEmpty){final ps=await client.from('profiles').select('id,nickname').inFilter('id',ownerIds);for(final x in ps as List){names['${x['id']}']='${x['nickname']??''}';}}\n    for (final place in places) {\n      place.ownerNickname=names[place.ownerId]??place.ownerNickname;\n      place.photoUrls = byPlace[place.id] ?? place.photoUrls;"
if old in s:s=s.replace(old,new,1)
if 'Future<void> deletePlace(String placeId)' not in s:
    s=s.replace("  @override Future<void> updatePlace(Place place) async => client.from('places').update(place.toSupabaseJson()).eq('id', place.id);", "  @override Future<void> updatePlace(Place place) async => client.from('places').update(place.toSupabaseJson()).eq('id', place.id);\n  @override Future<void> deletePlace(String placeId) async { await client.from('places').delete().eq('id',placeId); }")
# pending approval list also needs owner nickname.
oldp="@override Future<List<Place>> pendingPlaces() async { final rows=await client.from('places_view').select().eq('approval_status','pending').order('created_at',ascending:false); return (rows as List).map((e)=>Place.fromJson(Map<String,dynamic>.from(e))).toList(); }"
newp="@override Future<List<Place>> pendingPlaces() async { final rows=await client.from('places_view').select().eq('approval_status','pending').order('created_at',ascending:false); final out=(rows as List).map((e)=>Place.fromJson(Map<String,dynamic>.from(e))).toList(); final ids=out.map((e)=>e.ownerId).where((e)=>e.isNotEmpty).toSet().toList(); final names=<String,String>{}; if(ids.isNotEmpty){final ps=await client.from('profiles').select('id,nickname').inFilter('id',ids);for(final x in ps as List){names['${x['id']}']='${x['nickname']??''}';}} for(final x in out){x.ownerNickname=names[x.ownerId]??'';} return out; }"
if oldp in s:s=s.replace(oldp,newp,1)
p.write_text(s,encoding='utf-8')

# Record real last access time after successful server login.
p=Path('lib/repositories/auth_repository.dart'); s=p.read_text(encoding='utf-8')
old="        u = await currentUser();\n      } catch (_) { return null; }"
new="        u = await currentUser();\n        final au=client!.auth.currentUser; if(au!=null){try{await client!.from('profiles').update({'last_seen_at':DateTime.now().toIso8601String()}).eq('id',au.id);}catch(_){}}\n      } catch (_) { return null; }"
if old in s:s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')

# PLACE REGISTRATION + DETAIL.
p=Path('lib/screens/home_screen.dart'); s=p.read_text(encoding='utf-8')
old="OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new="OutlinedButton.icon(onPressed: () async { final remain=6-photos.length; if(remain<=0){_msg('장소사진은 최대 6장입니다.');return;} final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain); if(picked.isNotEmpty)setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:s=s.replace(old,new,1)
anchor="        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"
thumbs="""        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>setS(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"""
if anchor in s and 'photos.removeAt(i)' not in s:s=s.replace(anchor,thumbs,1)
detail="        if (p.address.isNotEmpty) Text(p.address),"
if detail in s and '최종 등록일자:' not in s:s=s.replace(detail,detail+"\n        Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n        if(p.createdAt!=null) Text('최종 등록일자: ${p.createdAt!.toLocal().toString().substring(0,16)}'),",1)
needle="        if (!p.isApproved && _isMine(p)) ...["
admin="""        if(widget.user.isAdministrator) ...[const SizedBox(height:10),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){Navigator.pop(ctx);_msg('장소 수정은 관리자 승인 화면에서 이용해주세요.');},icon:const Icon(Icons.edit),label:const Text('수정'))),const SizedBox(width:8),Expanded(child:FilledButton.tonalIcon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('장소 삭제'),content:Text('${p.name} 장소를 삭제할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('삭제'))]));if(ok==true){await widget.data.deletePlace(p.id);if(ctx.mounted)Navigator.pop(ctx);await _load();_msg('장소를 삭제했습니다.');}},icon:const Icon(Icons.delete_outline),label:const Text('삭제')))])],
"""
if needle in s and '장소를 삭제했습니다.' not in s:s=s.replace(needle,admin+needle,1)
p.write_text(s,encoding='utf-8')

# MARKET photo behavior + visible owner/date/status.
p=Path('lib/screens/vehicle_market_screen.dart'); s=p.read_text(encoding='utf-8')
s=s.replace("final d=await db.from('vehicle_market_listings').select().order('created_at',ascending:false);", "final d=await db.from('vehicle_market_listings').select().order('created_at',ascending:false); final ids=(d as List).map((e)=>'${e['owner_id']}').where((e)=>e.isNotEmpty).toSet().toList(); final names=<String,String>{}; if(ids.isNotEmpty){final ps=await db.from('profiles').select('id,nickname').inFilter('id',ids);for(final p in ps as List){names['${p['id']}']='${p['nickname']??''}';}} for(final x in d){x['owner_nickname']=names['${x['owner_id']}']??'';}")
old="OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
new="OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);if(p.isNotEmpty)ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20')),if(photos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>ss(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))"
if old in s:s=s.replace(old,new,1)
s=s.replace("const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))", "const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))")
p.write_text(s,encoding='utf-8')

# ADMIN MANAGEMENT requested search and timestamps.
p=Path('lib/screens/admin_management_screen.dart'); s=p.read_text(encoding='utf-8')
s=s.replace("return members.where((x)=>[_userId(x),_nickname(x),'${x['phone']??''}','${x['vehicle_name']??''}','${x['role']??''}','${x['account_status']??''}'].join(' ').toLowerCase().contains(q)).toList();", "return members.where((x)=>[_userId(x),_nickname(x)].join(' ').toLowerCase().contains(q)).toList();")
s=s.replace("hintText:'아이디 · 닉네임 · 휴대폰 · 차량 통합검색'", "hintText:'아이디 · 닉네임 통합검색'")
s=s.replace("MapEntry('가입일','${x['created_at']??''}')", "MapEntry('가입일','${x['created_at']??''}'),MapEntry('마지막 접속일자 및 시간','${x['last_seen_at']??'기록 없음'}')")
if 'String _nameById' not in s:s=s.replace("  void msg(String s)=>", "  String _nameById(dynamic id){for(final m in members){if('${m['id']}'=='$id')return _nickname(m).isEmpty?'닉네임 없음':_nickname(m);}return '닉네임 없음';}\n  String _dt(dynamic v){final d=DateTime.tryParse('$v')?.toLocal();return d==null?'-':d.toString().substring(0,16);}\n  void msg(String s)=>")
s=s.replace("subtitle:Text('${x['body']}\\n${x['status']=='answered'?'답변완료':'답변대기'}')", "subtitle:Text('${x['body']}\\n작성자: ${_nameById(x['author_id'])} · 요청: ${_dt(x['created_at'])}\\n${x['status']=='answered'?'답변완료':'답변대기'}')")
s=s.replace("subtitle:Text('${x['reason']}'),trailing:Text('${x['status']}')", "subtitle:Text('${x['reason']}\\n신고자: ${_nameById(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}'),isThreeLine:true,trailing:Text('${x['status']}')")
p.write_text(s,encoding='utf-8')

# ADMIN PLACE APPROVAL requester metadata.
p=Path('lib/screens/admin_screen.dart'); s=p.read_text(encoding='utf-8')
needle="                if (p.address.isNotEmpty) Text(p.address),"
if needle in s and '요청일시:' not in s:s=s.replace(needle,needle+"\n                Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n                if(p.createdAt!=null) Text('요청일시: ${p.createdAt!.toLocal().toString().substring(0,16)}'),",1)
p.write_text(s,encoding='utf-8')
print('requested fixes applied')
