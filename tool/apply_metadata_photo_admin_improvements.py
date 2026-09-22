from pathlib import Path

def patch(path, old, new, label):
    p=Path(path); s=p.read_text(encoding='utf-8')
    if new in s:
        print(label, 'already present'); return
    if old not in s:
        print(label, 'anchor changed; skipped'); return
    p.write_text(s.replace(old,new,1),encoding='utf-8'); print('patched',label)

# Place metadata used by normal detail + admin approval screens.
p=Path('lib/models/place.dart'); s=p.read_text(encoding='utf-8')
s=s.replace("    this.approvalStatus = 'pending',\n", "    this.approvalStatus = 'pending',\n    this.ownerNickname = '',\n    this.createdAt,\n    this.updatedAt,\n")
s=s.replace("  String approvalStatus;\n", "  String approvalStatus;\n  String ownerNickname;\n  DateTime? createdAt;\n  DateTime? updatedAt;\n")
s=s.replace("        'approvalStatus': approvalStatus,\n", "        'approvalStatus': approvalStatus,\n        'ownerNickname': ownerNickname,\n        'createdAt': createdAt?.toIso8601String(),\n        'updatedAt': updatedAt?.toIso8601String(),\n")
s=s.replace("        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n", "        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n        ownerNickname: '${j['ownerNickname'] ?? j['owner_nickname'] ?? ''}',\n        createdAt: DateTime.tryParse('${j['createdAt'] ?? j['created_at'] ?? ''}'),\n        updatedAt: DateTime.tryParse('${j['updatedAt'] ?? j['updated_at'] ?? ''}'),\n")
p.write_text(s,encoding='utf-8')

# Repository API: admin can delete a registered place.
p=Path('lib/repositories/app_data_repository.dart'); s=p.read_text(encoding='utf-8')
if 'Future<void> deletePlace(String placeId);' not in s:
    s=s.replace('  Future<void> updatePlace(Place place);','  Future<void> updatePlace(Place place);\n  Future<void> deletePlace(String placeId);')
p.write_text(s,encoding='utf-8')

p=Path('lib/repositories/local_repository.dart'); s=p.read_text(encoding='utf-8')
if 'Future<void> deletePlace(String placeId)' not in s:
    anchor='  @override\n  Future<List<Place>> pendingPlaces() async'
    method="  @override\n  Future<void> deletePlace(String placeId) async { final list=await _allPlaces(); list.removeWhere((p)=>p.id==placeId); await savePlaces(list); }\n\n"
    s=s.replace(anchor,method+anchor)
p.write_text(s,encoding='utf-8')

p=Path('lib/repositories/supabase_repository.dart'); s=p.read_text(encoding='utf-8')
# Enrich place owner nickname from profiles without changing DB view.
old="    for (final place in places) {\n      place.photoUrls = byPlace[place.id] ?? place.photoUrls;"
new="    final ownerIds=places.map((e)=>e.ownerId).where((e)=>e.isNotEmpty).toSet().toList();\n    final nickById=<String,String>{};\n    if(ownerIds.isNotEmpty){final ps=await client.from('profiles').select('id,nickname').inFilter('id',ownerIds);for(final r in ps as List){nickById['${r['id']}']='${r['nickname']??''}';}}\n    for (final place in places) {\n      place.ownerNickname = nickById[place.ownerId] ?? place.ownerNickname;\n      place.photoUrls = byPlace[place.id] ?? place.photoUrls;"
if old in s: s=s.replace(old,new,1)
if 'Future<void> deletePlace(String placeId)' not in s:
    s=s.replace("  @override Future<void> updatePlace(Place place) async => client.from('places').update(place.toSupabaseJson()).eq('id', place.id);", "  @override Future<void> updatePlace(Place place) async => client.from('places').update(place.toSupabaseJson()).eq('id', place.id);\n  @override Future<void> deletePlace(String placeId) async { await client.from('places').delete().eq('id',placeId); }")
p.write_text(s,encoding='utf-8')

# Track successful server logins for admin member detail.
p=Path('lib/repositories/auth_repository.dart'); s=p.read_text(encoding='utf-8')
old="        u = await currentUser();\n      } catch (_) { return null; }"
new="        u = await currentUser();\n        final au=client!.auth.currentUser; if(au!=null){try{await client!.from('profiles').update({'last_seen_at':DateTime.now().toIso8601String()}).eq('id',au.id);}catch(_){}}\n      } catch (_) { return null; }"
if old in s: s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')

# Home: append place photos, show removable thumbnails before submit, metadata + admin delete.
p=Path('lib/screens/home_screen.dart'); s=p.read_text(encoding='utf-8')
old="OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new="OutlinedButton.icon(onPressed: () async { final remain=6-photos.length; if(remain<=0){_msg('장소사진은 최대 6장입니다.');return;} final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain); setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:s=s.replace(old,new,1)
photo_anchor="        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"
photo_ui="""        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>setS(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"""
if photo_anchor in s and 'photos.removeAt(i)' not in s:s=s.replace(photo_anchor,photo_ui,1)
# Add helper formatter once.
if 'String _placeDate(' not in s:
    insert="  String _placeDate(DateTime? d){if(d==null)return '-';final x=d.toLocal();String z(int n)=>n.toString().padLeft(2,'0');return '${x.year}-${z(x.month)}-${z(x.day)} ${z(x.hour)}:${z(x.minute)}';}\n\n"
    s=s.replace('  Future<void> _showPlace(Place p) async {',insert+'  Future<void> _showPlace(Place p) async {',1)
# Detail metadata before reviews area: use stable address occurrence in sheet.
detail_anchor="        if (p.address.isNotEmpty) InkWell(onTap: () => _openExternalMap(p), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.navigation_outlined, size: 18), const SizedBox(width: 6), Expanded(child: Text(p.address, style: const TextStyle(decoration: TextDecoration.underline)))]))),"
meta="""        if (p.address.isNotEmpty) InkWell(onTap: () => _openExternalMap(p), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.navigation_outlined, size: 18), const SizedBox(width: 6), Expanded(child: Text(p.address, style: const TextStyle(decoration: TextDecoration.underline)))]))),
        if(p.ownerNickname.isNotEmpty)Text('등록자: ${p.ownerNickname}'),
        Text('최종등록일자: ${_placeDate(p.updatedAt ?? p.createdAt)}'),"""
if detail_anchor in s and '최종등록일자:' not in s:s=s.replace(detail_anchor,meta,1)
# Admin delete button near admin edit button if present.
admin_anchor="if(widget.user.isAdministrator)FilledButton.tonalIcon(onPressed:()=>_editPlaceAsAdmin(p),icon:const Icon(Icons.edit),label:const Text('관리자 정보 수정'))"
admin_new="if(widget.user.isAdministrator)Wrap(spacing:8,children:[FilledButton.tonalIcon(onPressed:()=>_editPlaceAsAdmin(p),icon:const Icon(Icons.edit),label:const Text('관리자 정보 수정')),OutlinedButton.icon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('등록장소 삭제'),content:Text('${p.name}을(를) 삭제할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('삭제'))]));if(ok==true){await widget.data.deletePlace(p.id);if(ctx.mounted)Navigator.pop(ctx);await _load();_msg('장소를 삭제했습니다.');}},icon:const Icon(Icons.delete_outline),label:const Text('장소 삭제'))])"
if admin_anchor in s:s=s.replace(admin_anchor,admin_new,1)
p.write_text(s,encoding='utf-8')

# Vehicle market: owner nickname/date, removable newly selected photos.
p=Path('lib/screens/vehicle_market_screen.dart'); s=p.read_text(encoding='utf-8')
old="Future<void> load() async { try { final d=await db.from('vehicle_market_listings').select().order('created_at',ascending:false); if(mounted)setState((){rows=List<Map<String,dynamic>>.from(d);loading=false;}); } catch(e)"
new="Future<void> load() async { try { final d=List<Map<String,dynamic>>.from(await db.from('vehicle_market_listings').select().order('created_at',ascending:false));final ids=d.map((x)=>'${x['owner_id']}').where((x)=>x.isNotEmpty).toSet().toList();final nm=<String,String>{};if(ids.isNotEmpty){final ps=await db.from('profiles').select('id,nickname').inFilter('id',ids);for(final p in ps as List){nm['${p['id']}']='${p['nickname']??''}';}}for(final x in d){x['_owner_nickname']=nm['${x['owner_id']}']??'';} if(mounted)setState((){rows=d;loading=false;}); } catch(e)"
if old in s:s=s.replace(old,new,1)
if 'String dt(dynamic v)' not in s:
    s=s.replace("  String money(dynamic v)", "  String dt(dynamic v){final d=DateTime.tryParse('$v')?.toLocal();if(d==null)return '-';String z(int n)=>n.toString().padLeft(2,'0');return '${d.year}-${z(d.month)}-${z(d.day)} ${z(d.hour)}:${z(d.minute)}';}\n  String money(dynamic v)",1)
btn="OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
if btn in s and 'photos.removeAt(i)' not in s:
    s=s.replace(btn,btn+",if(photos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>ss(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))",1)
contact="      if(mine)Wrap(spacing:8,children:"
if contact in s and "등록자: ${x['_owner_nickname']}" not in s:
    s=s.replace(contact,"      Text('등록자: ${('${x['_owner_nickname']??''}').isEmpty?'닉네임 없음':x['_owner_nickname']}'),Text('등록일자: ${dt(x['created_at'])}'),const SizedBox(height:8),\n"+contact,1)
p.write_text(s,encoding='utf-8')

# Admin integrated management: member search only id/nickname, last login, feedback/report nickname+time.
p=Path('lib/screens/admin_management_screen.dart'); s=p.read_text(encoding='utf-8')
s=s.replace("return members.where((x)=>[_userId(x),_nickname(x),'${x['phone']??''}','${x['vehicle_name']??''}','${x['role']??''}','${x['account_status']??''}'].join(' ').toLowerCase().contains(q)).toList();", "return members.where((x)=>[_userId(x),_nickname(x)].join(' ').toLowerCase().contains(q)).toList();")
s=s.replace("hintText:'아이디 · 닉네임 · 휴대폰 · 차량 통합검색'", "hintText:'아이디 · 닉네임 통합검색'")
s=s.replace("MapEntry('가입일','${x['created_at']??''}')", "MapEntry('가입일','${x['created_at']??''}'),MapEntry('마지막 접속일시','${x['last_seen_at']??'기록 없음'}')")
# Helpers for author nickname and local time.
if 'String _nameById(' not in s:
    s=s.replace("  void msg(String s)=>", "  String _nameById(dynamic id){final k='$id';for(final m in members){if('${m['id']}'==k)return _nickname(m).isEmpty?'닉네임 없음':_nickname(m);}return '닉네임 없음';}\n  String _dt(dynamic v){final d=DateTime.tryParse('$v')?.toLocal();if(d==null)return '-';String z(int n)=>n.toString().padLeft(2,'0');return '${d.year}-${z(d.month)}-${z(d.day)} ${z(d.hour)}:${z(d.minute)}';}\n  void msg(String s)=>",1)
s=s.replace("subtitle:Text('${x['body']}\\n${x['status']=='answered'?'답변완료':'답변대기'}')", "subtitle:Text('${x['body']}\\n작성자: ${_nameById(x['author_id'])} · 요청: ${_dt(x['created_at'])}\\n${x['status']=='answered'?'답변완료':'답변대기'}')")
s=s.replace("subtitle:Text('${x['reason']}'),trailing:Text('${x['status']}')", "subtitle:Text('${x['reason']}\\n신고자: ${_nameById(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}'),isThreeLine:true,trailing:Text('${x['status']}')")
p.write_text(s,encoding='utf-8')

# Admin approval list: place registrant nickname + request timestamp.
p=Path('lib/screens/admin_home_screen.dart'); s=p.read_text(encoding='utf-8')
old="subtitle:Text('${p.address}\\n${p.services.join(' · ')}'),isThreeLine:true"
new="subtitle:Text('${p.address}\\n등록자: ${p.ownerNickname.isEmpty?'닉네임 없음':p.ownerNickname} · 요청: ${p.createdAt?.toLocal().toString().substring(0,16)??'-'}\\n${p.services.join(' · ')}'),isThreeLine:true"
if old in s:s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('metadata/photo/admin improvements applied')
