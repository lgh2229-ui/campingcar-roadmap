import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../models/place_review.dart';
import '../models/review_comment.dart';
import '../repositories/app_data_repository.dart';
import '../repositories/auth_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.auth,
    required this.data,
    required this.onUserChanged,
    required this.onLogout,
    this.refreshSignal = 0,
    this.focusPlaceId,
  });

  final AppUser user;
  final AuthRepository auth;
  final AppDataRepository data;
  final ValueChanged<AppUser> onUserChanged;
  final Future<void> Function() onLogout;
  final int refreshSignal;
  final String? focusPlaceId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _reservationUrl(String note){for(final line in note.split('\n')){if(line.startsWith('[예약링크]'))return line.substring(6).trim();}return '';}
  String _visibleNote(String note)=>note.split('\n').where((e)=>!e.startsWith('[예약링크]')).join('\n').trim();
  String _noteWithReservation(String note,String url){final clean=_visibleNote(note);return url.trim().isEmpty?clean:'${clean.isEmpty?'':clean+'\n'}[예약링크]${url.trim()}';}

  final map = MapController();
  final search = TextEditingController();
  List<Place> places = [];
  Set<String> saved = {};
  int tab = 0;
  String filter = '전체';
  String savedFilter = '전체';
  LatLng center = const LatLng(37.5665, 126.9780);
  LatLng? selectedSpot;
  LatLng? currentLocation;
  Place? editingLocationPlace;
  bool locationPickMode = false;
  bool loading = false;
  bool _focusHandled=false;

  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];
  String get _currentAuthorId => widget.user.authId.isEmpty ? widget.user.userId : widget.user.authId;

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _locate();
  }

  Future<void> _load() async {
    try {
      places = await widget.data.places();
      saved = await widget.data.savedIds();
      if (mounted) setState(() {});
      if(!_focusHandled&&widget.focusPlaceId!=null){final hit=places.where((x)=>x.id==widget.focusPlaceId).toList();if(hit.isNotEmpty){_focusHandled=true;final p=hit.first;center=LatLng(p.latitude,p.longitude);map.move(center,17);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_showPlace(p);});}}
    } catch (e) {
      _msg('데이터를 불러오지 못했습니다: $e');
    }
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      center = LatLng(p.latitude, p.longitude);
      currentLocation = center;
      map.move(center, 15);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _selectSpot(LatLng point) {
    if(locationPickMode)return;
    selectedSpot = point;
    center = point;
    map.move(point, 17);
    setState(() {});
    _msg('등록 위치를 선택했습니다. 빨간 핀 위치로 등록됩니다.');
  }

  bool _isMine(Place p) => p.ownerId == _currentAuthorId;
  List<Place> get visiblePlaces {
    final rows = filter == '전체' ? places : places.where((p) => p.services.contains(filter)).toList();
    return rows;
  }

  List<List<Place>> get visiblePlaceGroups {
    const distance = 15.0;
    final groups = <List<Place>>[];
    for (final p in visiblePlaces) {
      List<Place>? target;
      for (final g in groups) {
        if (Geolocator.distanceBetween(g.first.latitude, g.first.longitude, p.latitude, p.longitude) <= distance) {
          target = g;
          break;
        }
      }
      if (target == null) {
        groups.add([p]);
      } else {
        target.add(p);
      }
    }
    return groups;
  }

  LatLng _groupPoint(List<Place> group) => LatLng(
        group.fold<double>(0, (sum, p) => sum + p.latitude) / group.length,
        group.fold<double>(0, (sum, p) => sum + p.longitude) / group.length,
      );

  List<String> _icons(Place p) {
    final out = <String>[];
    if (p.services.contains('급수')) out.add('💧');
    if (p.services.contains('블랙탱크 비움')) out.add('🚽');
    if (p.services.contains('노지/차박')) out.add('🅿️');
    if (p.services.contains('공중화장실')) out.add('🚻');
    return out.isEmpty ? ['📍'] : out;
  }

  String _filterLabel(String value) => value == '블랙탱크 비움' ? '블랙' : value == '공중화장실' ? '화장실' : value;
  String _approvalLabel(Place p) => switch (p.approvalStatus) {
        'pending' => '승인 진행중',
        'rejected' => '승인 반려',
        _ => '승인 완료',
      };

  Color _approvalColor(Place p, BuildContext context) => switch (p.approvalStatus) {
        'pending' => Theme.of(context).colorScheme.tertiaryContainer,
        'rejected' => Theme.of(context).colorScheme.errorContainer,
        _ => Theme.of(context).colorScheme.primaryContainer,
      };

  String _meters(int mm) => (mm / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  int? _metersToMm(String value) {
    final m = double.tryParse(value.trim());
    return m == null || m <= 0 ? null : (m * 1000).round();
  }

  Future<List<Map<String,dynamic>>> _koreanAddressSearch(String q) async {
    final r=await Supabase.instance.client.functions.invoke('korean-address-search',body:{'keyword':q});
    final data=Map<String,dynamic>.from(r.data as Map);
    if(data['error']!=null)throw Exception(data['error']);
    return (data['results'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<Map<String,dynamic>?> _pickKoreanAddress(String q) async {
    final data=await _koreanAddressSearch(q);
    if(data.isEmpty){_msg('도로명/지번 주소 검색 결과가 없습니다.');return null;}
    if(!mounted)return null;
    return showModalBottomSheet<Map<String,dynamic>>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:ListView.separated(
      shrinkWrap:true,itemCount:data.length,separatorBuilder:(_,__)=>const Divider(height:1),
      itemBuilder:(_,i){final row=data[i];final road='${row['roadAddr']??''}'.trim(),jibun='${row['jibunAddr']??''}'.trim();
        return ListTile(leading:const Icon(Icons.location_on_outlined),title:Text(road.isNotEmpty?road:jibun),subtitle:jibun.isNotEmpty&&jibun!=road?Text('지번  $jibun'):null,onTap:()=>Navigator.pop(ctx,row));}
    )));
  }

  Future<void> _searchAddress() async {
    final q=search.text.trim();if(q.isEmpty)return;
    try{
      final needle=q.toLowerCase();
      final local=places.where((p)=>p.name.toLowerCase().contains(needle)).toList();
      if(local.isNotEmpty){
        Place? picked;
        if(local.length==1){
          picked=local.first;
        }else if(mounted){
          picked=await showModalBottomSheet<Place>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:ListView.separated(
            shrinkWrap:true,itemCount:local.length,separatorBuilder:(_,__)=>const Divider(height:1),
            itemBuilder:(_,i){final p=local[i];return ListTile(leading:const Icon(Icons.place_outlined),title:Text(p.name),subtitle:p.address.trim().isEmpty?null:Text(p.address),onTap:()=>Navigator.pop(ctx,p));}
          )));
        }
        if(picked!=null){
          final point=LatLng(picked.latitude,picked.longitude);center=point;map.move(point,17);if(mounted)setState((){});
          return;
        }
      }
      final picked=await _pickKoreanAddress(q);if(picked==null)return;
      final lat=(picked['lat'] as num?)?.toDouble(),lon=(picked['lon'] as num?)?.toDouble();
      if(lat==null||lon==null){_msg('주소는 찾았지만 좌표를 확인하지 못했습니다.');return;}
      final point=LatLng(lat,lon);center=point;map.move(point,16);if(mounted)setState((){});
    }catch(e){_msg('검색에 실패했습니다: $e');}
  }

  String _cleanPart(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return ['대한민국', 'Republic of Korea', 'South Korea'].contains(s) ? '' : s;
  }

  String _pickPart(Map<String, dynamic> a, List<String> keys) {
    for (final k in keys) {
      final v = _cleanPart(a[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Future<String> _reverseAddress(LatLng p) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}&accept-language=ko&addressdetails=1&zoom=18');
      final r = await http.get(uri, headers: {'User-Agent': 'CampingCarRoadmap/1.9'});
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final raw = j['address'];
      if (raw is Map) {
        final a = Map<String, dynamic>.from(raw);
        final parts = <String>[];
        for (final v in [
          _pickPart(a, ['state', 'province']),
          _pickPart(a, ['city', 'municipality', 'county', 'town']),
          _pickPart(a, ['borough', 'district']),
          _pickPart(a, ['road', 'residential', 'pedestrian']),
          _pickPart(a, ['house_number']),
        ]) {
          if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
        }
        if (parts.length >= 3) return parts.join(' ');
      }
      var s = '${j['display_name'] ?? ''}'.replaceAll('대한민국', '').replaceAll('Republic of Korea', '').replaceAll('South Korea', '');
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList().reversed.join(' ');
    } catch (_) {
      return '';
    }
  }

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_mapPage(), _savedPage(), _myPlacesPage(), _profilePage()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: '저장'),
          NavigationDestination(icon: Icon(Icons.add_location_alt_outlined), selectedIcon: Icon(Icons.add_location_alt), label: '내등록'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }

  Widget _mapPage() => Stack(children: [
        FlutterMap(
          mapController: map,
          options: MapOptions(initialCenter: center, initialZoom: 14, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate), onLongPress: (_, p) => _selectSpot(p),onPositionChanged:(camera,hasGesture){if(locationPickMode&&hasGesture&&mounted)setState(()=>selectedSpot=camera.center);}),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.co.campingcarroadmap.app'),
            MarkerLayer(markers: [
              ...visiblePlaceGroups.map((group) {
                final p = group.first;
                final pending = group.any((x) => x.isPending && _isMine(x));
                return Marker(
                  point: _groupPoint(group),
                  width: 48,
                  height: 48,
                  child: GestureDetector(
                    onTap: () => _showPlaceGroup(group),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: pending ? Theme.of(context).colorScheme.tertiaryContainer : Colors.white,
                        border: Border.all(width: 2),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                      ),
                      child: group.length > 1
                          ? Stack(alignment: Alignment.center, children: [
                              const Icon(Icons.location_on, size: 26),
                              Positioned(right: 0, top: 0, child: Text('${group.length}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            ])
                          : Center(child: Text(_icons(p).take(3).join(), style: const TextStyle(fontSize: 17))),
                    ),
                  ),
                );
              }),
              if (currentLocation != null)
                Marker(point: currentLocation!, width: 34, height: 34, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.blue, width: 3), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)]), child: const Center(child: Icon(Icons.circle, color: Colors.blue, size: 14)))),
              if (selectedSpot != null)
                Marker(point: selectedSpot!, width: 100, height: 75, alignment: Alignment.topCenter, child: Column(children: [Text(locationPickMode?'수정 위치':'등록 위치', style: TextStyle(fontWeight: FontWeight.bold)), Icon(Icons.location_pin, color: Colors.red, size: 48)])),
            ]),
          ],
        ),
        Positioned(top: 10, left: 10, right: 10, child: Column(children: [
          Material(elevation: 3, borderRadius: BorderRadius.circular(12), child: Row(children: [Expanded(child: TextField(controller: search, onSubmitted: (_) => _searchAddress(), decoration: const InputDecoration(hintText: '등록 장소명 또는 주소 검색', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14)))), IconButton(onPressed: _searchAddress, icon: const Icon(Icons.search))])),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)))).toList())),
        ])),
        if (selectedSpot != null)
          Positioned(left:12,right:12,bottom:86,child:Card(child:ListTile(leading:const Icon(Icons.location_pin,color:Colors.red),title:Text('${selectedSpot!.latitude.toStringAsFixed(6)}, ${selectedSpot!.longitude.toStringAsFixed(6)}',style:const TextStyle(fontSize:12)),trailing:locationPickMode?Wrap(spacing:4,children:[TextButton(onPressed:(){setState((){locationPickMode=false;editingLocationPlace=null;selectedSpot=null;});},child:const Text('취소')),FilledButton(onPressed:()async{final target=editingLocationPlace,spot=selectedSpot;if(target==null||spot==null)return;final a=await _reverseAddress(spot);target.latitude=spot.latitude;target.longitude=spot.longitude;target.address=a;try{await widget.data.updatePlace(target);await _load();if(!mounted)return;setState((){locationPickMode=false;editingLocationPlace=null;selectedSpot=null;center=spot;});map.move(spot,17);_msg('위치와 주소를 반영했습니다.');}catch(e){_msg('위치 수정에 실패했습니다: $e');}},child:const Text('확인'))]):TextButton(onPressed:()=>setState(()=>selectedSpot=null),child:const Text('취소'))))),
        Positioned(right:14,bottom:18,child:Column(children:[
          if(!locationPickMode) FloatingActionButton.small(heroTag:'loc',onPressed:_locate,child:const Icon(Icons.my_location)),
          if(!locationPickMode) const SizedBox(height:10),
          if(!locationPickMode) FloatingActionButton.extended(heroTag: 'add', onPressed: () {
            if (selectedSpot == null) return _msg('지도에서 등록할 위치를 길게 눌러 빨간 핀을 먼저 찍어주세요.');
            _openAddPlace(selectedSpot!);
          }, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('장소등록')),
        ])),
      ]);

  Future<void> _showPlaceGroup(List<Place> group) async {
    if (group.length == 1) return _showPlace(group.first);
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView.separated(
      shrinkWrap: true,
      itemCount: group.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = group[i];
        return ListTile(
          leading: Text(_icons(p).join()),
          title: Text(p.name),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.address), if (!p.isApproved && _isMine(p)) Text(_approvalLabel(p), style: const TextStyle(fontWeight: FontWeight.bold))]),
          onTap: () { Navigator.pop(ctx); Future.delayed(const Duration(milliseconds: 100), () => _showPlace(p)); },
        );
      },
    )));
  }

  Widget _savedPage() {
    final all = places.where((p) => p.isApproved && saved.contains(p.id)).toList();
    final rows = savedFilter == '전체' ? all : all.where((p) => p.services.contains(savedFilter)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('저장한 장소')),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(_filterLabel(e)), selected: savedFilter == e, onSelected: (_) => setState(() => savedFilter = e)))).toList())),
        Expanded(child: rows.isEmpty ? const Center(child: Text('저장한 장소가 없습니다.')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
          final p = rows[i];
          return ListTile(
            leading: Text(_icons(p).join()),
            title: Text(p.name),
            subtitle: Text(p.address),
            onTap: () { setState(() => tab = 0); map.move(LatLng(p.latitude, p.longitude), 17); Future.delayed(const Duration(milliseconds: 150), () => _showPlace(p)); },
            trailing: IconButton(onPressed: () async { saved.remove(p.id); await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg('저장에서 해제했습니다.'); }, icon: const Icon(Icons.close)),
          );
        })),
      ]),
    );
  }

  Widget _myPlacesPage() {
    final rows = places.where(_isMine).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('내가 등록한 장소')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: rows.isEmpty
            ? ListView(children: const [SizedBox(height: 180), Center(child: Text('등록한 장소가 없습니다.'))])
            : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
                final p = rows[i];
                return Card(margin: const EdgeInsets.fromLTRB(12, 6, 12, 6), child: ListTile(
                  leading: CircleAvatar(backgroundColor: _approvalColor(p, context), child: Icon(p.isApproved ? Icons.check : p.isPending ? Icons.hourglass_top : Icons.close)),
                  title: Text(p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'), '')),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.address), Text(_approvalLabel(p), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  onTap: () => _showPlace(p),
                ));
              }),
      ),
    );
  }

  Widget _profilePage() => Scaffold(
        appBar: AppBar(title: const Text('내정보'), actions: [IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout))]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: ListTile(leading: const Icon(Icons.person), title: Text(widget.user.displayName), subtitle: Text('아이디 ${widget.user.userId}\n${widget.user.phone}${widget.user.phoneVerified ? ' · 인증완료' : ''}', maxLines: 2))),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _passwordGate, child: const Text('개인정보 변경')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _vehicleDialog, child: const Text('차량정보 변경')),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: _openMyResponses, icon: const Icon(Icons.mark_chat_read_outlined), label: const Text('내 문의 · 처리결과')),
          const SizedBox(height: 18),
          const Divider(),
          TextButton.icon(onPressed: _deleteAccount, icon: const Icon(Icons.delete_forever_outlined), label: const Text('회원탈퇴')),
        ]),
      );

  Future<void> _openMyResponses() async {
    final db=Supabase.instance.client;
    try{
      final a=await Future.wait([
        db.from('vehicle_market_reports').select().eq('reporter_id',_currentAuthorId).order('created_at',ascending:false),
        db.from('review_admin_tasks').select('*, reviews!inner(author_id,body,status), places(name)').eq('reviews.author_id',_currentAuthorId).order('created_at',ascending:false),
      ]);
      if(!mounted)return;
      final rows=<Map<String,dynamic>>[
        ...List<Map<String,dynamic>>.from(a[0]).map((x)=>({...x,'_kind':'report'})),
        ...List<Map<String,dynamic>>.from(a[1]).map((x)=>({...x,'_kind':'review'})),
      ]..sort((x,y)=>'${y['created_at']}'.compareTo('${x['created_at']}'));
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(child:SizedBox(
        height:MediaQuery.of(ctx).size.height*.82,
        child:Column(children:[
          const Padding(padding:EdgeInsets.fromLTRB(16,4,16,12),child:Text('내 문의 · 처리결과',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
          Expanded(child:rows.isEmpty?const Center(child:Text('확인할 신고나 검증리뷰가 없습니다.')):ListView.builder(itemCount:rows.length,itemBuilder:(_,i){
            final x=rows[i],isReview=x['_kind']=='review';
            final done=isReview?x['handled']==true:'${x['status']??''}'=='resolved';
            final reply='${x['admin_reply']??''}'.trim();
            final review=isReview?Map<String,dynamic>.from(x['reviews']??{}):<String,dynamic>{};
            final place=isReview?Map<String,dynamic>.from(x['places']??{}):<String,dynamic>{};
            return Card(margin:const EdgeInsets.fromLTRB(12,5,12,5),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(isReview?'검증리뷰 · ${place['name']??'장소'}':'중고캠핑카 신고',style:const TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              Text(isReview?'${x['reason']??''} · ${review['body']??''}':'${x['reason']??''}'),
              const SizedBox(height:8),
              Text(done?'처리완료':'처리대기',style:TextStyle(fontWeight:FontWeight.bold,color:done?Theme.of(ctx).colorScheme.primary:Theme.of(ctx).colorScheme.tertiary)),
              if(done&&reply.isNotEmpty)...[const Divider(height:20),const Text('관리자 답변',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:4),Text(reply)],
            ])));
          }))
        ])
      )));
    }catch(e){_msg('처리결과를 불러오지 못했습니다: $e');}
  }

  Future<void> _passwordGate() async {
    final c = TextEditingController();
    final entered = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('비밀번호 확인'), content: TextField(controller: c, obscureText: true, autofocus: true, onSubmitted: (_) => Navigator.pop(ctx, c.text)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('확인'))]));
    if (entered == null) return;
    final ok = await widget.auth.reauthenticatePassword(entered);
    if (!ok) return _msg('비밀번호가 일치하지 않습니다.');
    if (!mounted) return;
    _msg('본인 확인이 완료되었습니다.');
  }

  Future<void> _deleteAccount() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('회원탈퇴'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('계정과 관련 데이터가 삭제되며 복구할 수 없습니다.'), TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: '현재 비밀번호'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('탈퇴'))]));
    if (ok != true) return;
    if (!await widget.auth.reauthenticatePassword(c.text)) return _msg('비밀번호가 일치하지 않습니다.');
    try { await widget.auth.deleteAccount(); await widget.onLogout(); } catch (e) { _msg('회원탈퇴에 실패했습니다: $e'); }
  }

  Future<void> _vehicleDialog() async {
    String status = widget.user.vehicleStatus.isEmpty ? 'planned' : widget.user.vehicleStatus;
    String sanitation = widget.user.sanitationType;
    final name = TextEditingController(text: widget.user.vehicleName);
    final height = TextEditingController(text: widget.user.vehicleHeightMm == null ? '' : _meters(widget.user.vehicleHeightMm!));
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('차량정보'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<String>(value: 'planned', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('구매예정')),
        RadioListTile<String>(value: 'owned', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('보유중')),
        if (status == 'owned') ...[
          TextField(controller: name, decoration: const InputDecoration(labelText: '차량명/모델')),
          TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '진입 차량 높이', hintText: '예: 3.0', suffixText: 'm')),
          ...['블랙탱크', '그레이탱크', '카트리지'].map((e) => RadioListTile<String>(value: e, groupValue: sanitation, onChanged: (v) => setS(() => sanitation = v!), title: Text(e))),
        ],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')), FilledButton(onPressed: () async {
        final heightMm = status == 'owned' ? _metersToMm(height.text) : null;
        if (status == 'owned' && (name.text.trim().isEmpty || heightMm == null || sanitation.isEmpty)) return _msg('차량명, 높이(m), 위생설비를 모두 입력해주세요.');
        final u = await widget.auth.updateVehicle(status: status, name: status == 'owned' ? name.text.trim() : '', heightMm: heightMm, sanitation: status == 'owned' ? sanitation : '');
        widget.onUserChanged(u);
        if (ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('저장'))],
    )));
  }

  Future<void> _openAddPlace(LatLng spot) async {
    final name = TextEditingController();
    final hours = TextEditingController();
    final maxHeight = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final reservationUrl = TextEditingController();
    final selected = <String>{};
    final prices = <String, TextEditingController>{for (final s in ['급수', '블랙탱크 비움', '노지/차박', '공중화장실']) s: TextEditingController()};
    final photos = <XFile>[];
    String reservation = '예약불필요';
    final address = TextEditingController(text: await _reverseAddress(spot));
    if (!mounted) return;

    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('새 장소 등록'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Text('등록 위치 ${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}')),
        TextField(controller: name, decoration: const InputDecoration(labelText: '장소명')),
        TextField(controller: address, decoration: const InputDecoration(labelText: '주소 (한국 도로명주소)')),
        ...prices.entries.map((e) => Row(children: [Checkbox(value: selected.contains(e.key), onChanged: (v) => setS(() { if (v == true) { selected.add(e.key); } else { selected.remove(e.key); e.value.clear(); } })), Expanded(flex: 2, child: Text(e.key)), Expanded(flex: 3, child: TextField(controller: e.value, enabled: selected.contains(e.key), decoration: const InputDecoration(hintText: '금액 / 무료')))])),
        TextField(controller: hours, decoration: const InputDecoration(labelText: '운영시간')),
        DropdownButtonFormField<String>(initialValue: reservation, items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => reservation = v ?? reservation), decoration: const InputDecoration(labelText: '예약 여부')),
        if(reservation=='예약필수') TextField(controller:reservationUrl,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'예약 링크',hintText:'https://...')),
        TextField(controller: maxHeight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '진입 최대 높이', hintText: '예: 3.2', suffixText: 'm')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처')),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}')),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        const Text('등록 후 관리자 승인 전까지 일반 사용자 지도에는 공개되지 않습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')), FilledButton(onPressed: loading ? null : () async {
        if (name.text.trim().isEmpty || selected.isEmpty) return _msg('장소명과 서비스 항목을 입력해주세요.');
        for (final s in selected) { if (prices[s]!.text.trim().isEmpty) return _msg('$s 금액을 입력해주세요. 무료면 "무료"라고 입력해주세요.'); }
        if (photos.isEmpty) return _msg('장소사진을 1장 이상 등록해주세요.');
        setState(() => loading = true);
        try {
          final p = Place(
            id: const Uuid().v4(),
            name: name.text.trim(),
            latitude: spot.latitude,
            longitude: spot.longitude,
            address: address.text.trim(),
            services: selected.toList(),
            prices: {for (final s in selected) s: prices[s]!.text.trim()},
            hours: hours.text.trim(),
            reservation: reservation,
            maxHeightMm: maxHeight.text.trim().isEmpty ? null : _metersToMm(maxHeight.text),
            phone: phone.text.trim(),
            note: _noteWithReservation(note.text,reservation=='예약필수'?reservationUrl.text:''),
            ownerId: _currentAuthorId,
            approvalStatus: 'pending',
          );
          await widget.data.addPlace(p);
          p.photoUrls = await widget.data.uploadPlacePhotos(p.id, photos.map((e) => File(e.path)).toList());
          selectedSpot = null;
          if (ctx.mounted) Navigator.pop(ctx);
          await _load();
          if (mounted) setState(() => tab = 2);
          _msg('장소가 접수되었습니다. 관리자 승인 진행중입니다.');
        } catch (e) {
          _msg('장소 등록에 실패했습니다: $e');
        } finally {
          if (mounted) setState(() => loading = false);
        }
      }, child: const Text('등록 요청'))],
    )));
  }

  void _showPhotoViewer(List<String> photos, int initial) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (viewerContext) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initial + 1}/${photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: photos.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: photos[i].startsWith('http://') || photos[i].startsWith('https://')
                ? Image.network(photos[i], fit: BoxFit.contain)
                : Image.file(File(photos[i]), fit: BoxFit.contain),
          ),
        ),
      ),
    )));
  }

  Widget _placePhoto(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(value, width: 210, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 210, child: Center(child: Icon(Icons.broken_image_outlined))));
    }
    return Image.file(File(value), width: 210, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 210, child: Center(child: Icon(Icons.broken_image_outlined))));
  }

  Future<void> _showPlace(Place p) async {
    final reviews = p.isApproved ? await widget.data.reviews(p.id) : <PlaceReview>[];
    if (!mounted) return;
    await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .42,
      maxChildSize: .94,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Row(children: [Expanded(child: Text(p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'), ''), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), if (!p.isApproved && _isMine(p)) Chip(label: Text(_approvalLabel(p)), backgroundColor: _approvalColor(p, context))]),
        const SizedBox(height: 6),
        Text(p.services.join(' · ')),
        if (p.address.isNotEmpty) Text(p.address),
        if (p.ownerNickname.trim().isNotEmpty || p.createdAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname} · 등록일자: ${p.createdAt == null ? '-' : '${p.createdAt!.toLocal().year.toString().padLeft(4, '0')}.${p.createdAt!.toLocal().month.toString().padLeft(2, '0')}.${p.createdAt!.toLocal().day.toString().padLeft(2, '0')} ${p.createdAt!.toLocal().hour.toString().padLeft(2, '0')}:${p.createdAt!.toLocal().minute.toString().padLeft(2, '0')}'}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
        if (p.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: p.photoUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => InkWell(onTap: () => _showPhotoViewer(p.photoUrls, i), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _placePhoto(p.photoUrls[i]))))),
        ],
        const SizedBox(height: 12),
        if (p.hours.isNotEmpty) Text('운영시간: ${p.hours}'),
        if (p.reservation.isNotEmpty) Text('예약: ${p.reservation}'),
        if(p.reservation=='예약필수'&&_reservationUrl(p.note).isNotEmpty) OutlinedButton.icon(onPressed:()async{final raw=_reservationUrl(p.note);final u=Uri.tryParse(raw.startsWith('http')?raw:'https://$raw');if(u==null||!await launchUrl(u,mode:LaunchMode.externalApplication))_msg('예약 링크를 열 수 없습니다.');},icon:const Icon(Icons.open_in_new),label:const Text('예약 페이지 열기')),
        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),
        if (p.maxHeightMm != null) Text('진입 최대 높이: ${_meters(p.maxHeightMm!)}m'),
        if (p.maxHeightMm != null && widget.user.vehicleHeightMm != null) _heightCompatibility(p),
        if (_visibleNote(p.note).isNotEmpty) Text('이용방법/주의사항: ${_visibleNote(p.note)}'),
        if (!p.isApproved && _isMine(p)) ...[
          const SizedBox(height: 16),
          Card(color: _approvalColor(p, context), child: Padding(padding: const EdgeInsets.all(14), child: Text(p.isPending ? '관리자가 등록 내용을 확인 중입니다. 승인되면 전체 사용자 지도에 공개됩니다.' : '등록이 반려되었습니다. 관리자 검토 결과를 확인해 주세요.'))),
        ],
        if (p.isApproved) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.tonalIcon(onPressed: () async {
              final wasSaved = saved.contains(p.id);
              if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }
              try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }
            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),
          ]),
          if(widget.user.isAdministrator)...[const SizedBox(height:8),Row(children:[Expanded(child:FilledButton.tonalIcon(onPressed:(){Navigator.pop(ctx);_adminEditPlace(p);},icon:const Icon(Icons.edit_outlined),label:const Text('장소 수정'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:(){Navigator.pop(ctx);_adminDeletePlace(p);},icon:const Icon(Icons.delete_outline),label:const Text('장소 삭제')))])],
          const Divider(height: 28),
          const Text('검증 리뷰', style: TextStyle(fontWeight: FontWeight.bold)),
          if (reviews.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('아직 검증 리뷰가 없습니다.')),
          ...reviews.map((r) => _reviewTile(p, r)),
        ],
      ]),
    ));
  }

  Widget _heightCompatibility(Place p) {
    final vehicle = widget.user.vehicleHeightMm!;
    final limit = p.maxHeightMm!;
    final margin = limit - vehicle;
    final (icon, label) = margin < 0 ? ('⛔', '진입불가') : margin < 100 ? ('⚠️', '진입주의') : ('✅', '진입가능');
    return Padding(padding: const EdgeInsets.only(top: 4), child: Text('$icon 내 차량 ${_meters(vehicle)}m · $label (여유 ${(margin / 1000).toStringAsFixed(2)}m)'));
  }

  Widget _reviewTile(Place p, PlaceReview r) {
    final label = switch (r.status) { 'ok' => '이용가능', 'change' => '변경', 'bad' => '이용불가', _ => r.status };
    final mine = r.authorId == _currentAuthorId;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(switch (r.status) { 'ok' => '✅', 'change' => '⚠️', 'bad' => '⛔', _ => '📝' }),
            const SizedBox(width: 8),
            Expanded(child: Text('$label · ${r.authorName}${mine ? ' · 내 리뷰' : ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (mine) PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _editReview(p, r); if (v == 'delete') await _deleteReview(p, r); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))]),
          ]),
          if (r.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.body)),
          if (r.photoUrls.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: SizedBox(height: 82, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: r.photoUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) => InkWell(onTap: () => _showPhotoViewer(r.photoUrls, i), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _placePhoto(r.photoUrls[i])))))),
          FutureBuilder<List<ReviewComment>>(future:widget.data.reviewComments(r.id),builder:(_,snap){final cc=snap.data??const <ReviewComment>[];return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(cc.isNotEmpty)...[const Divider(),...cc.map((x)=>Padding(padding:const EdgeInsets.only(bottom:6),child:Text('${x.authorName.isEmpty?'사용자':x.authorName} · ${x.body}')))],Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async {await _openReviewComments(r);if(mounted)setState((){});}, icon: const Icon(Icons.chat_bubble_outline, size: 18), label: Text(cc.isEmpty?'댓글':'댓글 ${cc.length}')))]);}),
        ]),
      ),
    );
  }

  Future<void> _openReviewComments(PlaceReview review) async {
    List<ReviewComment> comments = [];
    try { comments = await widget.data.reviewComments(review.id); } catch (e) { return _msg('댓글을 불러오지 못했습니다: $e'); }
    if (!mounted) return;
    final c = TextEditingController();
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SizedBox(height: MediaQuery.of(ctx).size.height * .62, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('리뷰 댓글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(child: comments.isEmpty ? const Center(child: Text('아직 댓글이 없습니다.')) : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) { final x = comments[i]; return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.reply), title: Text(x.authorName), subtitle: Text(x.body)); })),
        Row(children: [
          Expanded(child: TextField(controller: c, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: '댓글 입력', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton(onPressed: () async {
            if (c.text.trim().isEmpty) return;
            try { await widget.data.addReviewComment(reviewId: review.id, body: c.text); c.clear(); comments = await widget.data.reviewComments(review.id); setS(() {}); } catch (e) { _msg('댓글 등록에 실패했습니다: $e'); }
          }, child: const Text('등록')),
        ]),
      ])),
    )));
  }

  Future<void> _openReview(Place p) async {
    String status='ok'; final body=TextEditingController(); final photos=<XFile>[];
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(title:const Text('검증리뷰'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[RadioListTile<String>(value:'ok',groupValue:status,onChanged:(v)=>setS(()=>status=v!),title:const Text('이용가능')),RadioListTile<String>(value:'change',groupValue:status,onChanged:(v)=>setS(()=>status=v!),title:const Text('변경')),RadioListTile<String>(value:'bad',groupValue:status,onChanged:(v)=>setS(()=>status=v!),title:const Text('이용불가')),TextField(controller:body,maxLength:200,maxLines:3,decoration:const InputDecoration(labelText:'리뷰 내용')),Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:()async{final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:10);if(picked.isNotEmpty)setS((){for(final x in picked){if(photos.length<10&&!photos.any((e)=>e.path==x.path))photos.add(x);}});},icon:const Icon(Icons.add_photo_alternate_outlined),label:Text('사진 첨부 ('+photos.length.toString()+'/10)'))),if(photos.isNotEmpty)SizedBox(height:72,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:photos.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i)=>Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:72,fit:BoxFit.cover)),Positioned(right:0,top:0,child:InkWell(onTap:()=>setS(()=>photos.removeAt(i)),child:const CircleAvatar(radius:11,child:Icon(Icons.close,size:14))))]))),if(status!='ok')const Padding(padding:EdgeInsets.only(top:8),child:Text('변경/이용불가 리뷰는 관리자 검증리뷰 확인 목록에도 자동 등록됩니다.',style:TextStyle(fontSize:12)))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('등록'))])));
    if(ok!=true)return;try{await widget.data.addReview(placeId:p.id,status:status,body:body.text,photos:photos.map((e)=>File(e.path)).toList());_msg('검증리뷰가 등록되었습니다.');await _load();if(mounted)_showPlace(p);}catch(e){_msg('리뷰 등록에 실패했습니다: '+e.toString());}
  }

  Future<void> _adminEditPlace(Place p) async {
    if(!widget.user.isAdministrator)return _msg('관리자만 수정할 수 있습니다.');final name=TextEditingController(text:p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'),'')),address=TextEditingController(text:p.address),hours=TextEditingController(text:p.hours),height=TextEditingController(text:p.maxHeightMm==null?'':_meters(p.maxHeightMm!)),phone=TextEditingController(text:p.phone),note=TextEditingController(text:_visibleNote(p.note)),reservationUrl=TextEditingController(text:_reservationUrl(p.note));final existingPhotos=List<String>.from(p.photoUrls);final removedPhotos=<String>{};final newPhotos=<XFile>[];final serviceNames=['급수','블랙탱크 비움','노지/차박','공중화장실'];final selected=p.services.toSet();final prices={for(final s in serviceNames)s:TextEditingController(text:p.prices[s]??'')};String reservation=['예약불필요','예약필수','전화문의'].contains(p.reservation)?p.reservation:'전화문의';double editLat=p.latitude,editLon=p.longitude;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(title:const Text('장소 정보 수정'),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'장소명')),TextField(controller:address,decoration:const InputDecoration(labelText:'주소')),const SizedBox(height:8),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(10)),child:Text('수정 위치 ${editLat.toStringAsFixed(6)}, ${editLon.toStringAsFixed(6)}')),Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()async{final pos=await Geolocator.getCurrentPosition();final pt=LatLng(pos.latitude,pos.longitude);final a=await _reverseAddress(pt);setS((){editLat=pt.latitude;editLon=pt.longitude;address.text=a;});},icon:const Icon(Icons.my_location),label:const Text('내 현위치로 지정')),OutlinedButton.icon(onPressed:()async{Navigator.pop(ctx,false);final pt=LatLng(editLat,editLon);setState((){tab=0;locationPickMode=true;editingLocationPlace=p;selectedSpot=pt;center=pt;});map.move(pt,17);_msg('지도를 움직여 빨간 핀을 원하는 위치에 맞춘 뒤 확인을 누르세요.');},icon:const Icon(Icons.map_outlined),label:const Text('지도에서 위치 지정'))]),...serviceNames.map((s)=>Row(children:[Checkbox(value:selected.contains(s),onChanged:(v)=>setS((){if(v==true)selected.add(s);else{selected.remove(s);prices[s]!.clear();}})),Expanded(flex:2,child:Text(s)),Expanded(flex:3,child:TextField(controller:prices[s],enabled:selected.contains(s),decoration:const InputDecoration(hintText:'금액 / 무료')))])),TextField(controller:hours,decoration:const InputDecoration(labelText:'운영시간')),DropdownButtonFormField<String>(initialValue:reservation,items:['예약불필요','예약필수','전화문의'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setS(()=>reservation=v??reservation),decoration:const InputDecoration(labelText:'예약 여부')),if(reservation=='예약필수')TextField(controller:reservationUrl,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'예약 링크',hintText:'https://...')),TextField(controller:height,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'진입 최대 높이',suffixText:'m')),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'문의연락처')),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'이용방법 / 주의사항')),const SizedBox(height:12),Align(alignment:Alignment.centerLeft,child:Text('장소 사진',style:TextStyle(fontWeight:FontWeight.bold))),if(existingPhotos.where((x)=>!removedPhotos.contains(x)).isNotEmpty)SizedBox(height:92,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:existingPhotos.where((x)=>!removedPhotos.contains(x)).length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i){final url=existingPhotos.where((x)=>!removedPhotos.contains(x)).elementAt(i);return Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:_placePhoto(url)),Positioned(right:0,top:0,child:InkWell(onTap:()=>setS(()=>removedPhotos.add(url)),child:const CircleAvatar(radius:12,child:Icon(Icons.close,size:15))))]);})),if(newPhotos.isNotEmpty)SizedBox(height:92,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:newPhotos.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i)=>Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(newPhotos[i].path),width:120,height:92,fit:BoxFit.cover)),Positioned(right:0,top:0,child:InkWell(onTap:()=>setS(()=>newPhotos.removeAt(i)),child:const CircleAvatar(radius:12,child:Icon(Icons.close,size:15))))]))),Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:()async{final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:10);if(picked.isNotEmpty)setS((){for(final x in picked){if(existingPhotos.length-removedPhotos.length+newPhotos.length<10&&!newPhotos.any((e)=>e.path==x.path))newPhotos.add(x);}});},icon:const Icon(Icons.add_photo_alternate_outlined),label:Text('사진 추가 ('+(existingPhotos.length-removedPhotos.length+newPhotos.length).toString()+'/10)')))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('수정 저장'))])));if(ok!=true)return;if(name.text.trim().isEmpty||selected.isEmpty)return _msg('장소명과 서비스 항목을 입력해주세요.');for(final s in selected){if(prices[s]!.text.trim().isEmpty)return _msg(s+' 금액을 입력해주세요.');}p.name=name.text.trim();p.address=address.text.trim();p.latitude=editLat;p.longitude=editLon;p.services=selected.toList();p.prices={for(final s in selected)s:prices[s]!.text.trim()};p.hours=hours.text.trim();p.reservation=reservation;p.maxHeightMm=height.text.trim().isEmpty?null:_metersToMm(height.text);p.phone=phone.text.trim();p.note=_noteWithReservation(note.text,reservation=='예약필수'?reservationUrl.text:'');try{await widget.data.updatePlace(p);for(final url in removedPhotos){await widget.data.deletePlacePhoto(p.id,url);}final kept=existingPhotos.where((x)=>!removedPhotos.contains(x)).toList();final added=newPhotos.isEmpty?<String>[]:await widget.data.uploadPlacePhotos(p.id,newPhotos.map((e)=>File(e.path)).toList());p.photoUrls=[...kept,...added];await _load();_msg('장소 정보를 수정했습니다.');}catch(e){_msg('장소 수정에 실패했습니다: '+e.toString());}
  }
  Future<void> _adminDeletePlace(Place p) async {if(!widget.user.isAdministrator)return _msg('관리자만 삭제할 수 있습니다.');final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('장소 삭제'),content:Text('「'+p.name+'」 장소를 삭제할까요?\n삭제하면 복구할 수 없습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('삭제'))]));if(ok!=true)return;try{await widget.data.deletePlace(p.id);await _load();_msg('장소를 삭제했습니다.');}catch(e){_msg('장소 삭제에 실패했습니다: '+e.toString());}}

  Future<void> _editReview(Place p, PlaceReview r) async {
    String status = r.status;
    final body = TextEditingController(text: r.body);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('내 리뷰 수정'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<String>(value: 'ok', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('이용가능')),
        RadioListTile<String>(value: 'change', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('변경')),
        RadioListTile<String>(value: 'bad', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('이용불가')),
        TextField(controller: body, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: '리뷰 내용')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('수정 저장'))],
    )));
    if (ok != true) return;
    try { await widget.data.updateReview(reviewId: r.id, status: status, body: body.text); _msg('리뷰를 수정했습니다.'); await _load(); if(mounted){Navigator.of(context).pop(); final hit=places.where((x)=>x.id==p.id).toList(); if(hit.isNotEmpty)_showPlace(hit.first);} } catch (e) { _msg('리뷰 수정에 실패했습니다: $e'); }
  }

  Future<void> _deleteReview(Place p, PlaceReview r) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('리뷰 삭제'), content: const Text('이 리뷰를 삭제할까요?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제'))]));
    if (ok != true) return;
    try { await widget.data.deleteReview(r.id); _msg('리뷰를 삭제했습니다.'); await _load(); if(mounted){Navigator.of(context).pop(); final hit=places.where((x)=>x.id==p.id).toList(); if(hit.isNotEmpty)_showPlace(hit.first);} } catch (e) { _msg('리뷰 삭제에 실패했습니다: $e'); }
  }
}
