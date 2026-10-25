from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text()
start = s.index('  Future<void> _openAddPlace(LatLng spot) async {')
end = s.index('  Widget _placePhoto(String value) {', start)
method = r'''  Future<void> _openAddPlace(LatLng spot) async {
    var registrationPoint = spot;
    final name = TextEditingController();
    final hours = TextEditingController();
    final maxHeight = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final lookup = await _reverseKoreanParcel(registrationPoint);
    var verifiedParcel=(lookup['jibunAddr']??'').toString().trim();
    var roadAddress=(lookup['roadAddr']??'').toString().trim();
    bool parcelVerified=verifiedParcel.isNotEmpty;
    final address = TextEditingController(text:verifiedParcel);
    final prices = <String, TextEditingController>{
      '블랙탱크 비움': TextEditingController(),
      '급수': TextEditingController(),
      '노지/차박': TextEditingController(),
      '공중화장실': TextEditingController(),
    };
    final selected = <String>{};
    const noPriceServices = <String>{'제작','매매','A/S','부품·용품'};
    final photos = <XFile>[];
    String reservation = '예약불필요';
    bool saving = false;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => StatefulBuilder(
          builder: (pageContext, setPageState) => Scaffold(
            appBar: AppBar(title: const Text('새 장소 등록'), leading: IconButton(icon: const Icon(Icons.close), onPressed: saving ? null : () => Navigator.pop(pageContext))),
            body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(pageContext).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Text('정확한 지도 지정 좌표 (길찾기 기준)\n${registrationPoint.latitude.toStringAsFixed(7)}, ${registrationPoint.longitude.toStringAsFixed(7)}')),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: '장소명', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller:address,
                onChanged:(v)=>setPageState(()=>parcelVerified=v.trim()==verifiedParcel&&verifiedParcel.isNotEmpty),
                decoration:const InputDecoration(
                  labelText:'지번주소 (필수 · 읍/면/리 + 번지)',
                  helperText:'지정한 핀에서 확인한 실제 지번으로만 등록할 수 있습니다.',
                  helperMaxLines:2,border:OutlineInputBorder())),
              const SizedBox(height:5),
              Row(children:[
                Icon(parcelVerified?Icons.verified_outlined:Icons.error_outline,
                  size:18,color:parcelVerified?Colors.green:Colors.orange),
                const SizedBox(width:7),
                Expanded(child:Text(parcelVerified
                  ? '지번 확인됨 · 등록 위치와 연결된 지번입니다'
                  : '지번 미확인 · 도로명만으로는 등록할 수 없습니다',
                  style:const TextStyle(fontSize:12))),
              ]),
              if(roadAddress.isNotEmpty)Padding(
                padding:const EdgeInsets.only(top:5),
                child:Text('참고 도로명: $roadAddress',
                  style:const TextStyle(fontSize:12))),
              Align(alignment:Alignment.centerLeft,child:TextButton.icon(
                onPressed:saving?null:()async{
                  final resolved=await _reverseKoreanParcel(registrationPoint);
                  final lot=(resolved['jibunAddr']??'').toString().trim();
                  setPageState((){
                    verifiedParcel=lot;
                    roadAddress=(resolved['roadAddr']??'').toString().trim();
                    parcelVerified=lot.isNotEmpty;
                    address.text=lot;
                  });
                  if(lot.isEmpty)_msg('해당 좌표의 지번 조회가 실패했습니다. 주소 검색에서 실제 필지를 확인해 주세요.');
                  else _msg('지정한 위치의 지번주소를 확인했습니다.');
                },
                icon:const Icon(Icons.location_searching),
                label:const Text('찍은 위치에서 지번 다시 조회'))),
              Align(alignment:Alignment.centerLeft,child:TextButton.icon(
                onPressed:saving?null:()async{
                  try{
                    final query=address.text.trim().isNotEmpty
                      ?address.text.trim()
                      :name.text.trim().isNotEmpty
                        ?name.text.trim():'태안군 남면';
                    final selected=await _pickKoreanAddress(query);
                    if(selected==null)return;
                    final lat=(selected['lat'] as num?)?.toDouble();
                    final lon=(selected['lon'] as num?)?.toDouble();
                    final lot=(selected['jibunAddr']??'').toString().trim();
                    if(lat==null||lon==null||lot.isEmpty){
                      _msg('확인 가능한 지번과 위치가 있는 검색 결과를 선택해 주세요.');return;
                    }
                    final meters=Geolocator.distanceBetween(
                      registrationPoint.latitude,registrationPoint.longitude,lat,lon);
                    if(meters>200){
                      _msg('선택한 지번은 표시한 핀에서 ${meters.round()}m 떨어져 있습니다. 정확한 필지를 다시 확인해 주세요.');
                      return;
                    }
                    setPageState((){
                      verifiedParcel=lot;
                      parcelVerified=true;
                      roadAddress=(selected['roadAddr']??'').toString().trim();
                      address.text=lot;
                    });
                    _msg('지번 확인 완료 · 찍은 핀 좌표는 바꾸지 않았습니다.');
                  }catch(e){_msg('지번 검색 실패: $e');}
                },
                icon:const Icon(Icons.fact_check_outlined),
                label:const Text('한국 지번주소 검색·확인 (핀 유지)'))),
              Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:saving?null:()async{var point=registrationPoint;final pickerMap=MapController();final picked=await showDialog<LatLng>(context:pageContext,builder:(mctx)=>StatefulBuilder(builder:(mctx,setM)=>Dialog(child:SizedBox(width:520,height:620,child:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,12,8,8),child:Row(children:[const Expanded(child:Text('지도에서 위치 지정',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(mctx),icon:const Icon(Icons.close))])),const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('원하는 위치를 길게 누른 뒤 이 위치 적용을 누르세요.')),const SizedBox(height:8),Expanded(child:FlutterMap(mapController:pickerMap,options:MapOptions(initialCenter:point,initialZoom:16,onLongPress:(_,v)=>setM(()=>point=v)),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'kr.co.campingcarroadmap.app'),MarkerLayer(markers:[Marker(point:point,width:54,height:54,child:const Icon(Icons.location_pin,color:Colors.red,size:54))])])),Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton(onPressed:()=>Navigator.pop(mctx),child:const Text('취소'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>Navigator.pop(mctx,point),child:const Text('이 위치 적용')))]))])))));if(picked!=null){
                  final result=await _reverseKoreanParcel(picked);
                  final lot=(result['jibunAddr']??'').toString().trim();
                  setPageState((){
                    registrationPoint=picked;
                    verifiedParcel=lot;
                    roadAddress=(result['roadAddr']??'').toString().trim();
                    address.text=lot;
                    parcelVerified=lot.isNotEmpty;
                  });
                  if(lot.isEmpty)_msg('지정 위치의 지번을 확인할 수 없습니다. 주소 검색으로 필지를 선택해 주세요.');
                }},icon:const Icon(Icons.map_outlined),label:const Text('주소 검색이 안 되면 지도에서 직접 위치 지정'))),
              const SizedBox(height: 18), const Text('서비스 항목 및 금액', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 6),
              ...prices.entries.map((e) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: Padding(padding: const EdgeInsets.fromLTRB(4, 4, 10, 4), child: Row(children: [
                Checkbox(value: selected.contains(e.key), onChanged: saving ? null : (v) => setPageState(() { if (v == true) { selected.add(e.key); } else { selected.remove(e.key); e.value.clear(); } })),
                Expanded(flex: 2, child: Text(e.key)), Expanded(flex: 3, child: TextField(controller: e.value, enabled: selected.contains(e.key) && !saving, decoration: const InputDecoration(hintText: '금액 / 무료', isDense: true))),
              ])))),
              GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:3.0,crossAxisSpacing:8,mainAxisSpacing:8,children:noPriceServices.map((service)=>Card(margin:EdgeInsets.zero,child:CheckboxListTile(dense:true,value:selected.contains(service),onChanged:saving?null:(v)=>setPageState((){if(v==true){selected.add(service);}else{selected.remove(service);}}),title:Text(service=='A/S'?'A/S':service=='부품·용품'?'부품/용품':service),controlAffinity:ListTileControlAffinity.leading,contentPadding:const EdgeInsets.symmetric(horizontal:8)))).toList()),
              RecreationPicker(
                selected: selected,
                enabled: !saving,
                onToggle: (activity) => setPageState(() {
                  if (!selected.add(activity)) selected.remove(activity);
                }),
              ),
              const SizedBox(height: 12), TextField(controller: hours, enabled: !saving, decoration: const InputDecoration(labelText: '운영시간', border: OutlineInputBorder())),
              const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: reservation, items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: saving ? null : (v) => reservation = v ?? reservation, decoration: const InputDecoration(labelText: '예약 여부', border: OutlineInputBorder())),
              const SizedBox(height: 12), TextField(controller: maxHeight, enabled: !saving, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '진입 최대 높이', hintText: '예: 3.2', suffixText: 'm', border: OutlineInputBorder())),
              const SizedBox(height: 12), TextField(controller: phone, enabled: !saving, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처', border: OutlineInputBorder())),
              const SizedBox(height: 12), TextField(controller: note, enabled: !saving, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: saving ? null : () async {
                  final remain = 6 - photos.length;
                  if (remain <= 0) { ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text('장소사진은 최대 6장입니다.'))); return; }
                  try {
                    final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
                    if (!pageContext.mounted || picked.isEmpty) return;
                    final additions = picked.take(remain).toList();
                    setPageState(() => photos.addAll(additions));
                  } catch (e) {
                    if (pageContext.mounted) ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text('사진 선택에 실패했습니다. 다시 시도해주세요.')));
                  }
                },
                icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'),
              ),
              if (photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 10, runSpacing: 10, children: List.generate(photos.length, (i) {
                final photo = photos[i];
                return SizedBox(key: ValueKey(photo.path), width: 100, height: 86, child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photo.path), fit: BoxFit.cover))),
                  Positioned(right: -4, top: -4, child: IconButton.filled(tooltip: '사진 삭제', constraints: const BoxConstraints.tightFor(width: 36, height: 36), padding: EdgeInsets.zero, onPressed: saving ? null : () => setPageState(() => photos.removeAt(i)), icon: const Icon(Icons.close, size: 20))),
                ]));
              }))),
              const SizedBox(height: 4), const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14), const Text('등록 후 관리자 승인 전까지 일반 사용자 지도에는 공개되지 않습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: saving ? null : () async {
                void msg(String text) => ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(text)));
                if (name.text.trim().isEmpty || selected.isEmpty) { msg('장소명과 서비스 항목을 입력해주세요.'); return; }
                for (final service in selected.where(prices.containsKey)) { if (prices[service]!.text.trim().isEmpty) { msg('$service 금액을 입력해주세요. 무료면 "무료"라고 입력해주세요.'); return; } }
                if (photos.isEmpty) { msg('장소사진을 1장 이상 등록해주세요.'); return; }
                if (!parcelVerified || verifiedParcel.isEmpty || address.text.trim()!=verifiedParcel) {
                  msg('정확한 지번주소를 확인해야 등록할 수 있습니다. 찍은 핀의 지번을 다시 조회하거나 검색 결과에서 확인해 주세요.');
                  return;
                }
                setPageState(() => saving = true);
                try {
                  final place = Place(id: const Uuid().v4(), name: name.text.trim(), latitude: registrationPoint.latitude, longitude: registrationPoint.longitude, address: address.text.trim(), services: selected.toList(), prices: {for (final service in selected.where(prices.containsKey)) service: prices[service]!.text.trim()}, hours: hours.text.trim(), reservation: reservation, maxHeightMm: maxHeight.text.trim().isEmpty ? null : _metersToMm(maxHeight.text), phone: phone.text.trim(), note: note.text.trim(), ownerId: _currentAuthorId, approvalStatus: 'pending');
                  await widget.data.addPlace(place);
                  place.photoUrls = await widget.data.uploadPlacePhotos(place.id, photos.map((e) => File(e.path)).toList());
                  selectedSpot = null;
                  if (pageContext.mounted) Navigator.pop(pageContext);
                  await _load(); if (mounted) setState(() => tab = 2); _msg('장소가 접수되었습니다. 관리자 승인 진행중입니다.');
                } catch (e) { if (pageContext.mounted) { ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text('장소 등록에 실패했습니다: $e'))); setPageState(() => saving = false); } }
              }, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_location_alt_outlined), label: Text(saving ? '등록 중...' : '등록 요청')),
            ])),
          ),
        ),
      ),
    );
  }

'''
# hard validation on the actual method injected earliest in CI
for token in ['pickMultiImage(imageQuality: 82)', 'photos.addAll(additions)', 'Image.file(File(photo.path)', 'photos.removeAt(i)']:
    if token not in method: raise SystemExit('missing '+token)
if 'photos\n                          ..clear()' in method or 'photos.clear()' in method: raise SystemExit('photo clear must not exist')
p.write_text(s[:start] + method + s[end:])
