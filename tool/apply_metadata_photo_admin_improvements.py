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
    final selected=<String>{...p.services};
    final prices=<String,TextEditingController>{for(final s in ['급수','블랙탱크 비움','노지/차박','공중화장실']) s:TextEditingController(text:p.prices[s]??'')};
    String reservation=p.reservation.isEmpty?'예약불필요':p.reservation;
    LatLng editedPoint=LatLng(p.latitude,p.longitude);
    var addressPointApplied=false;
    Future<void> pickPointOnMap() async {
      final picked=await showDialog<LatLng>(context:context,builder:(ctx){
        var point=editedPoint;
        final pickerMap=MapController();
        return StatefulBuilder(builder:(ctx,setP)=>Dialog(child:SizedBox(width:520,height:620,child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,12,8,8),child:Row(children:[const Expanded(child:Text('지도에서 위치 지정',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))])),
          const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('지도를 이동한 뒤 원하는 위치를 길게 누르세요. 빨간 핀이 실제 저장 위치입니다.')),
          const SizedBox(height:8),
          Expanded(child:FlutterMap(mapController:pickerMap,options:MapOptions(initialCenter:point,initialZoom:16,onLongPress:(_,p)=>setP(()=>point=p)),children:[
            TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'kr.co.campingcarroadmap.app'),
            MarkerLayer(markers:[Marker(point:point,width:54,height:54,child:const Icon(Icons.location_pin,color:Colors.red,size:54))]),
          ])),
          Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton(onPressed:()=>Navigator.pop(ctx),child:const Text('취소'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>Navigator.pop(ctx,point),child:const Text('이 위치 적용')))])),
        ]))));
      });
      if(picked!=null){editedPoint=picked;addressPointApplied=true;}
    }
    Future<void> applyAddress(String value) async {
      final q=value.trim();if(q.isEmpty)throw Exception('주소를 입력해주세요.');
      final picked=await _pickKoreanAddress(q);
      if(picked==null)throw Exception('주소 선택이 취소되었습니다.');
      final lat=(picked['lat'] as num?)?.toDouble(),lon=(picked['lon'] as num?)?.toDouble();
      if(lat==null||lon==null)throw Exception('주소 좌표를 확인하지 못했습니다.');
      address.text='${picked['roadAddr']??''}'.trim().isNotEmpty?'${picked['roadAddr']}':'${picked['jibunAddr']??q}';
      editedPoint=LatLng(lat,lon);addressPointApplied=true;
    }
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setS)=>AlertDialog(title:const Text('장소 수정 (관리자)'),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'장소명')),
      TextField(controller:address,decoration:const InputDecoration(labelText:'주소'),onSubmitted:(v)async{await applyAddress(v);setS((){});}),
      Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{try{await applyAddress(address.text);setS((){});_msg('주소 위치를 찾았습니다. 저장을 누르면 아이콘 위치가 변경됩니다.');}catch(e){_msg('$e');}},icon:const Icon(Icons.location_searching),label:const Text('주소 위치 적용'))),
      Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{await pickPointOnMap();setS((){});if(addressPointApplied)_msg('지도에서 위치를 지정했습니다. 저장을 누르면 아이콘 위치가 변경됩니다.');},icon:const Icon(Icons.map_outlined),label:const Text('주소 검색이 안 되면 지도에서 직접 위치 지정'))),
      ...prices.entries.map((e)=>Row(children:[Checkbox(value:selected.contains(e.key),onChanged:(v)=>setS((){if(v==true){selected.add(e.key);}else{selected.remove(e.key);e.value.clear();}})),Expanded(flex:2,child:Text(e.key)),Expanded(flex:3,child:TextField(controller:e.value,enabled:selected.contains(e.key),decoration:const InputDecoration(hintText:'금액 / 무료')))])),
      TextField(controller:hours,decoration:const InputDecoration(labelText:'운영시간')),
      DropdownButtonFormField<String>(initialValue:reservation,items:['예약불필요','예약필수','전화문의'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>reservation=v??reservation,decoration:const InputDecoration(labelText:'예약 여부')),
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
    if(name.text.trim().isEmpty||selected.isEmpty){_msg('장소명과 서비스 항목을 입력해주세요.');return;}
    for(final s in selected){if(prices[s]!.text.trim().isEmpty){_msg('$s 금액을 입력해주세요. 무료면 "무료"라고 입력해주세요.');return;}}
    if(keptPhotos.isEmpty&&newPhotos.isEmpty){_msg('장소사진을 1장 이상 남겨주세요.');return;}
    if(address.text.trim()!=p.address.trim()&&!addressPointApplied){_msg('주소가 변경되었습니다. 먼저 주소 위치 적용을 눌러 위치를 선택해주세요.');return;}
    p.name=name.text.trim();p.address=address.text.trim();p.latitude=editedPoint.latitude;p.longitude=editedPoint.longitude;p.services=selected.toList();p.prices={for(final s in selected)s:prices[s]!.text.trim()};p.hours=hours.text.trim();p.reservation=reservation;p.phone=phone.text.trim();p.note=note.text.trim();p.maxHeightMm=height.text.trim().isEmpty?null:_metersToMm(height.text);
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
if 'var registrationPoint=spot;' not in add:
    add=add.replace("    final name = TextEditingController();","    var registrationPoint=spot;\n    final name = TextEditingController();",1)
    add=add.replace("final address = TextEditingController(text: await _reverseAddress(spot));","final address = TextEditingController(text: await _reverseAddress(registrationPoint));",1)
    add=add.replace("spot.latitude.toStringAsFixed(6)","registrationPoint.latitude.toStringAsFixed(6)").replace("spot.longitude.toStringAsFixed(6)","registrationPoint.longitude.toStringAsFixed(6)")
    addr="TextField(controller: address, decoration: const InputDecoration(labelText: '주소 (한국 도로명주소)')),"
    addr_new="""TextField(controller: address, decoration: const InputDecoration(labelText: '주소 (도로명/지번)')),
        Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{try{final picked=await _pickKoreanAddress(address.text.trim());if(picked==null)return;final lat=(picked['lat'] as num?)?.toDouble(),lon=(picked['lon'] as num?)?.toDouble();if(lat==null||lon==null){_msg('주소 좌표를 확인하지 못했습니다.');return;}final road=(picked['roadAddr']??'').toString().trim();final jibun=(picked['jibunAddr']??'').toString().trim();address.text=road.isNotEmpty?road:(jibun.isNotEmpty?jibun:address.text);registrationPoint=LatLng(lat,lon);setS((){});_msg('주소 위치를 적용했습니다.');}catch(e){_msg('$e');}},icon:const Icon(Icons.location_searching),label:const Text('주소 위치 적용'))),
        Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{var point=registrationPoint;final pickerMap=MapController();final picked=await showDialog<LatLng>(context:context,builder:(mctx)=>StatefulBuilder(builder:(mctx,setM)=>Dialog(child:SizedBox(width:520,height:620,child:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,12,8,8),child:Row(children:[const Expanded(child:Text('지도에서 위치 지정',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(mctx),icon:const Icon(Icons.close))])),const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('원하는 위치를 길게 누른 뒤 이 위치 적용을 누르세요.')),const SizedBox(height:8),Expanded(child:FlutterMap(mapController:pickerMap,options:MapOptions(initialCenter:point,initialZoom:16,onLongPress:(_,v)=>setM(()=>point=v)),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'kr.co.campingcarroadmap.app'),MarkerLayer(markers:[Marker(point:point,width:54,height:54,child:const Icon(Icons.location_pin,color:Colors.red,size:54))])])),Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton(onPressed:()=>Navigator.pop(mctx),child:const Text('취소'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>Navigator.pop(mctx,point),child:const Text('이 위치 적용')))]))])))));if(picked!=null){registrationPoint=picked;setS((){});}},icon:const Icon(Icons.map_outlined),label:const Text('주소 검색이 안 되면 지도에서 직접 위치 지정'))),"""
    if addr not in add: raise SystemExit('registration address anchor missing')
    add=add.replace(addr,addr_new,1)
    add=add.replace("latitude: spot.latitude,","latitude: registrationPoint.latitude,",1).replace("longitude: spot.longitude,","longitude: registrationPoint.longitude,",1)
    s=s[:start]+add+s[end:]
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
