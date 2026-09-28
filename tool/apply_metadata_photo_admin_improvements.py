from pathlib import Path

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')

if 'Future<void> _adminEditPlace(Place p)' not in s:
    anchor='  Future<void> _showPlace(Place p) async {'
    if anchor not in s: raise SystemExit('showPlace anchor missing')
    method=r'''  Future<void> _adminEditPlace(Place p) async {
    if (!widget.user.isAdministrator) return;
    final name=TextEditingController(text:p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'),''));
    final address=TextEditingController(text:p.address);
    final hours=TextEditingController(text:p.hours);
    final phone=TextEditingController(text:p.phone);
    final note=TextEditingController(text:p.note);
    final height=TextEditingController(text:p.maxHeightMm==null?'':(p.maxHeightMm!/1000).toString());
    final keptPhotos=<String>[...p.photoUrls];
    final newPhotos=<XFile>[];
    LatLng editedPoint=LatLng(p.latitude,p.longitude);
    Future<void> applyAddress(String value) async {
      final q=value.trim();if(q.isEmpty)throw Exception('주소를 입력해주세요.');
      Future<List<dynamic>> search(String query) async {
        final uri=Uri.parse('https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&countrycodes=kr&accept-language=ko&q=${Uri.encodeQueryComponent(query)}');
        final r=await http.get(uri,headers:{'User-Agent':'CampingCarRoadmap/1.9'});
        if(r.statusCode!=200)throw Exception('주소 위치 검색 실패 (HTTP ${r.statusCode})');
        return jsonDecode(r.body) as List;
      }
      var rows=await search(q);
      if(rows.isEmpty){
        final simplified=q.replaceAll(RegExp(r'\\([^)]*\\)'),' ').replaceAll(RegExp(r'\\s+'),' ').trim();
        if(simplified!=q)rows=await search(simplified);
      }
      if(rows.isEmpty){
        final roadOnly=q.replaceAll(RegExp(r'\\s+\\d+(?:-\\d+)?(?:\\s+.*)?    }
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setS)=>AlertDialog(title:const Text('장소 수정 (관리자)'),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'장소명')),
      TextField(controller:address,decoration:const InputDecoration(labelText:'주소'),onSubmitted:(v)async{await applyAddress(v);setS((){});}),
      Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{try{await applyAddress(address.text);setS((){});_msg('주소 위치를 찾았습니다. 저장을 누르면 아이콘 위치가 변경됩니다.');}catch(e){_msg('$e');}},icon:const Icon(Icons.location_searching),label:const Text('주소 위치 적용'))),
      TextField(controller:hours,decoration:const InputDecoration(labelText:'운영시간')),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'문의연락처')),
      TextField(controller:height,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'진입 최대 높이',suffixText:'m')),
      TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'이용방법 / 주의사항')),
      const SizedBox(height:12),
      if(keptPhotos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:keptPhotos.map((url)=>Stack(children:[
        ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(url,width:92,height:92,fit:BoxFit.cover)),
        Positioned(right:0,top:0,child:IconButton.filled(onPressed:()=>setS(()=>keptPhotos.remove(url)),icon:const Icon(Icons.close,size:18),tooltip:'기존 사진 삭제')),
      ])).toList()),
      if(newPhotos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:newPhotos.map((photo)=>Stack(children:[
        ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photo.path),width:92,height:92,fit:BoxFit.cover)),
        Positioned(right:0,top:0,child:IconButton.filled(onPressed:()=>setS(()=>newPhotos.remove(photo)),icon:const Icon(Icons.close,size:18),tooltip:'추가 사진 삭제')),
      ])).toList()),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:()async{final room=6-keptPhotos.length-newPhotos.length;if(room<=0){_msg('사진은 최대 6장입니다.');return;}final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:room);setS(()=>newPhotos.addAll(picked.take(room)));},icon:const Icon(Icons.add_photo_alternate_outlined),label:Text('사진 추가 (${keptPhotos.length+newPhotos.length}/6)')),
      const Text('기존 사진은 X로 삭제하고 새 사진을 추가할 수 있습니다. 최소 1장은 남겨주세요.',style:TextStyle(fontSize:12)),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('저장'))])));
    if(ok!=true)return;
    if(keptPhotos.isEmpty&&newPhotos.isEmpty){_msg('장소사진을 1장 이상 남겨주세요.');return;}
    try{await applyAddress(address.text);}catch(e){_msg('$e');return;}
    p.name=name.text.trim();p.address=address.text.trim();p.latitude=editedPoint.latitude;p.longitude=editedPoint.longitude;p.hours=hours.text.trim();p.phone=phone.text.trim();p.note=note.text.trim();p.maxHeightMm=height.text.trim().isEmpty?null:_metersToMm(height.text);
    try{
      final uploaded=newPhotos.isEmpty?<String>[]:await widget.data.uploadPlacePhotos(p.id,newPhotos.map((e)=>File(e.path)).toList());
      p.photoUrls=[...keptPhotos,...uploaded];
      await widget.data.updatePlace(p);await _load();_msg('장소를 수정했습니다.');
    }catch(e){_msg('장소 수정에 실패했습니다: $e');}
  }

'''
    s=s.replace(anchor,method+anchor,1)

show_start=s.find('  Future<void> _showPlace(Place p) async {')
if show_start<0: raise SystemExit('showPlace missing')
if "Text('최종 등록일자:" not in s[show_start:]:
    pos=-1; token=''
    for c in ['children: [','children:[']:
        x=s.find(c,show_start)
        if x>=0: pos=x; token=c; break
    if pos<0: raise SystemExit('showPlace children anchor missing')
    insert=pos+len(token)
    meta="\n        Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n        Text('최종 등록일자: ${p.createdAt==null ? '-' : p.createdAt!.toLocal().toString().substring(0,16)}'),"
    s=s[:insert]+meta+s[insert:]

if "label: const Text('장소 수정')" not in s:
    anchor="        if (!p.isApproved && _isMine(p)) ...["
    if anchor not in s: raise SystemExit('admin button insertion anchor missing')
    admin=r'''        if (widget.user.isAdministrator) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); Future.delayed(const Duration(milliseconds: 120), () => _adminEditPlace(p)); }, icon: const Icon(Icons.edit_outlined), label: const Text('장소 수정'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.tonalIcon(onPressed: () async { final ok = await showDialog<bool>(context: context,builder: (d) => AlertDialog(title: const Text('장소 삭제'),content: Text('${p.name} 장소를 삭제할까요?'),actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제'))])); if (ok == true) { await widget.data.deletePlace(p.id); if (ctx.mounted) Navigator.pop(ctx); await _load(); _msg('장소를 삭제했습니다.'); } },icon: const Icon(Icons.delete_outline),label: const Text('장소 삭제'))),
            ],
          ),
        ],
'''
    s=s.replace(anchor,admin+anchor,1)

start=s.find('  Future<void> _openAddPlace('); end=s.find('  Widget _placePhoto(',start)
if start<0 or end<0: raise SystemExit('add-place boundaries missing')
add=s[start:end]
# Accept formatting variants produced by the preceding photo patch.
photo_groups=[
 ['builder: (pageContext, setPageState)'],
 ['pickMultiImage(imageQuality: 82)'],
 ['photos.addAll(additions)'],
 ['Image.file(File(photo.path)'],
 ['photos.removeAt(i)'],
]
missing=[group[0] for group in photo_groups if not any(x in add for x in group)]
if 'photos.clear()' in add or missing: raise SystemExit('PHOTO REGRESSION: '+','.join(missing))
for token in ["Text('등록자:","Text('최종 등록일자:",'Future<void> _adminEditPlace(Place p)',"label: const Text('장소 수정')","label: const Text('장소 삭제')",'if (widget.user.isAdministrator)']:
    if token not in s: raise SystemExit('HOME FEATURE MISSING: '+token)
p.write_text(s,encoding='utf-8')

m=Path('lib/screens/admin_management_screen.dart').read_text(encoding='utf-8')
management_required=["아이디 · 닉네임 통합검색","'${_userId(x)} ${_nickname(x)}'.toLowerCase().contains(q)","마지막접속일자 및 시간","x['last_seen_at']","x['status']=='sold'?'판매완료':'판매중'","등록자 ${_name(x['owner_id'])}","${_dt(x['created_at'])}","작성자: ${_name(x['author_id'])} · 요청:","신고자: ${_name(x['reporter_id'])} · 요청:"]
missing=[x for x in management_required if x not in m]
if missing: raise SystemExit('ADMIN MANAGEMENT FEATURE MISSING: '+','.join(missing))
a=Path('lib/repositories/auth_repository.dart').read_text(encoding='utf-8')
if "update({'last_seen_at':DateTime.now().toIso8601String()})" not in a: raise SystemExit('last_seen_at login update missing')
print('OK: requests 3-9 verified; multi-photo preserved')
),'').trim();
        if(roadOnly.isNotEmpty&&roadOnly!=q)rows=await search(roadOnly);
      }
      if(rows.isEmpty)throw Exception('주소를 자동으로 찾지 못했습니다. 지도에서 위치를 직접 지정해주세요.');
      editedPoint=LatLng(double.parse('${rows.first['lat']}'),double.parse('${rows.first['lon']}'));
    }
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setS)=>AlertDialog(title:const Text('장소 수정 (관리자)'),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'장소명')),
      TextField(controller:address,decoration:const InputDecoration(labelText:'주소'),onSubmitted:(v)async{await applyAddress(v);setS((){});}),
      Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{try{await applyAddress(address.text);setS((){});_msg('주소 위치를 찾았습니다. 저장을 누르면 아이콘 위치가 변경됩니다.');}catch(e){_msg('$e');}},icon:const Icon(Icons.location_searching),label:const Text('주소 위치 적용'))),
      TextField(controller:hours,decoration:const InputDecoration(labelText:'운영시간')),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'문의연락처')),
      TextField(controller:height,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'진입 최대 높이',suffixText:'m')),
      TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'이용방법 / 주의사항')),
      const SizedBox(height:12),
      if(keptPhotos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:keptPhotos.map((url)=>Stack(children:[
        ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(url,width:92,height:92,fit:BoxFit.cover)),
        Positioned(right:0,top:0,child:IconButton.filled(onPressed:()=>setS(()=>keptPhotos.remove(url)),icon:const Icon(Icons.close,size:18),tooltip:'기존 사진 삭제')),
      ])).toList()),
      if(newPhotos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:newPhotos.map((photo)=>Stack(children:[
        ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photo.path),width:92,height:92,fit:BoxFit.cover)),
        Positioned(right:0,top:0,child:IconButton.filled(onPressed:()=>setS(()=>newPhotos.remove(photo)),icon:const Icon(Icons.close,size:18),tooltip:'추가 사진 삭제')),
      ])).toList()),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:()async{final room=6-keptPhotos.length-newPhotos.length;if(room<=0){_msg('사진은 최대 6장입니다.');return;}final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:room);setS(()=>newPhotos.addAll(picked.take(room)));},icon:const Icon(Icons.add_photo_alternate_outlined),label:Text('사진 추가 (${keptPhotos.length+newPhotos.length}/6)')),
      const Text('기존 사진은 X로 삭제하고 새 사진을 추가할 수 있습니다. 최소 1장은 남겨주세요.',style:TextStyle(fontSize:12)),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('저장'))])));
    if(ok!=true)return;
    if(keptPhotos.isEmpty&&newPhotos.isEmpty){_msg('장소사진을 1장 이상 남겨주세요.');return;}
    try{await applyAddress(address.text);}catch(e){_msg('$e');return;}
    p.name=name.text.trim();p.address=address.text.trim();p.latitude=editedPoint.latitude;p.longitude=editedPoint.longitude;p.hours=hours.text.trim();p.phone=phone.text.trim();p.note=note.text.trim();p.maxHeightMm=height.text.trim().isEmpty?null:_metersToMm(height.text);
    try{
      final uploaded=newPhotos.isEmpty?<String>[]:await widget.data.uploadPlacePhotos(p.id,newPhotos.map((e)=>File(e.path)).toList());
      p.photoUrls=[...keptPhotos,...uploaded];
      await widget.data.updatePlace(p);await _load();_msg('장소를 수정했습니다.');
    }catch(e){_msg('장소 수정에 실패했습니다: $e');}
  }

'''
    s=s.replace(anchor,method+anchor,1)

show_start=s.find('  Future<void> _showPlace(Place p) async {')
if show_start<0: raise SystemExit('showPlace missing')
if "Text('최종 등록일자:" not in s[show_start:]:
    pos=-1; token=''
    for c in ['children: [','children:[']:
        x=s.find(c,show_start)
        if x>=0: pos=x; token=c; break
    if pos<0: raise SystemExit('showPlace children anchor missing')
    insert=pos+len(token)
    meta="\n        Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n        Text('최종 등록일자: ${p.createdAt==null ? '-' : p.createdAt!.toLocal().toString().substring(0,16)}'),"
    s=s[:insert]+meta+s[insert:]

if "label: const Text('장소 수정')" not in s:
    anchor="        if (!p.isApproved && _isMine(p)) ...["
    if anchor not in s: raise SystemExit('admin button insertion anchor missing')
    admin=r'''        if (widget.user.isAdministrator) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); Future.delayed(const Duration(milliseconds: 120), () => _adminEditPlace(p)); }, icon: const Icon(Icons.edit_outlined), label: const Text('장소 수정'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.tonalIcon(onPressed: () async { final ok = await showDialog<bool>(context: context,builder: (d) => AlertDialog(title: const Text('장소 삭제'),content: Text('${p.name} 장소를 삭제할까요?'),actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제'))])); if (ok == true) { await widget.data.deletePlace(p.id); if (ctx.mounted) Navigator.pop(ctx); await _load(); _msg('장소를 삭제했습니다.'); } },icon: const Icon(Icons.delete_outline),label: const Text('장소 삭제'))),
            ],
          ),
        ],
'''
    s=s.replace(anchor,admin+anchor,1)

start=s.find('  Future<void> _openAddPlace('); end=s.find('  Widget _placePhoto(',start)
if start<0 or end<0: raise SystemExit('add-place boundaries missing')
add=s[start:end]
# Accept formatting variants produced by the preceding photo patch.
photo_groups=[
 ['builder: (pageContext, setPageState)'],
 ['pickMultiImage(imageQuality: 82)'],
 ['photos.addAll(additions)'],
 ['Image.file(File(photo.path)'],
 ['photos.removeAt(i)'],
]
missing=[group[0] for group in photo_groups if not any(x in add for x in group)]
if 'photos.clear()' in add or missing: raise SystemExit('PHOTO REGRESSION: '+','.join(missing))
for token in ["Text('등록자:","Text('최종 등록일자:",'Future<void> _adminEditPlace(Place p)',"label: const Text('장소 수정')","label: const Text('장소 삭제')",'if (widget.user.isAdministrator)']:
    if token not in s: raise SystemExit('HOME FEATURE MISSING: '+token)
p.write_text(s,encoding='utf-8')

m=Path('lib/screens/admin_management_screen.dart').read_text(encoding='utf-8')
management_required=["아이디 · 닉네임 통합검색","'${_userId(x)} ${_nickname(x)}'.toLowerCase().contains(q)","마지막접속일자 및 시간","x['last_seen_at']","x['status']=='sold'?'판매완료':'판매중'","등록자 ${_name(x['owner_id'])}","${_dt(x['created_at'])}","작성자: ${_name(x['author_id'])} · 요청:","신고자: ${_name(x['reporter_id'])} · 요청:"]
missing=[x for x in management_required if x not in m]
if missing: raise SystemExit('ADMIN MANAGEMENT FEATURE MISSING: '+','.join(missing))
a=Path('lib/repositories/auth_repository.dart').read_text(encoding='utf-8')
if "update({'last_seen_at':DateTime.now().toIso8601String()})" not in a: raise SystemExit('last_seen_at login update missing')
print('OK: requests 3-9 verified; multi-photo preserved')
