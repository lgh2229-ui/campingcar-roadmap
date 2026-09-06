import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../models/place_review.dart';
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
  });
  final AppUser user;
  final AuthRepository auth;
  final AppDataRepository data;
  final ValueChanged<AppUser> onUserChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final map = MapController();
  final search = TextEditingController();
  List<Place> places = [];
  Set<String> saved = {};
  int tab = 0;
  String filter = '전체';
  String savedFilter = '전체';
  LatLng center = const LatLng(37.5665, 126.9780);
  LatLng? selectedSpot;
  bool loading = false;

  static const serviceFilters = ['전체', '블랙탱크 비움', '급수', '노지/차박', '공중화장실'];

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
    } catch (e) {
      _msg('데이터를 불러오지 못했습니다.');
    }
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      center = LatLng(p.latitude, p.longitude);
      map.move(center, 15);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _selectSpot(LatLng point) {
    selectedSpot = point;
    center = point;
    map.move(point, 17);
    setState(() {});
    _msg('등록 위치를 선택했습니다. 아래 빨간 핀 위치가 실제 등록 위치입니다.');
  }

  List<Place> get visiblePlaces => filter == '전체' ? places : places.where((p) => p.services.contains(filter)).toList();

  List<List<Place>> get visiblePlaceGroups {
    const groupDistanceMeters = 15.0;
    final groups = <List<Place>>[];
    for (final place in visiblePlaces) {
      List<Place>? target;
      for (final group in groups) {
        final anchor = group.first;
        final distance = Geolocator.distanceBetween(
          anchor.latitude,
          anchor.longitude,
          place.latitude,
          place.longitude,
        );
        if (distance <= groupDistanceMeters) {
          target = group;
          break;
        }
      }
      if (target == null) {
        groups.add([place]);
      } else {
        target.add(place);
      }
    }
    return groups;
  }

  LatLng _groupPoint(List<Place> group) {
    final lat = group.fold<double>(0, (sum, p) => sum + p.latitude) / group.length;
    final lng = group.fold<double>(0, (sum, p) => sum + p.longitude) / group.length;
    return LatLng(lat, lng);
  }

  Future<void> _showPlaceGroup(List<Place> group) async {
    if (group.length == 1) return _showPlace(group.first);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: group.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = group[i];
            return ListTile(
              leading: Text(_icons(p).join(), style: const TextStyle(fontSize: 22)),
              title: Text(p.name),
              subtitle: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(sheetContext);
                Future.delayed(const Duration(milliseconds: 120), () => _showPlace(p));
              },
            );
          },
        ),
      ),
    );
  }

  List<String> _icons(Place p) {
    final out = <String>[];
    if (p.services.contains('급수')) out.add('💧');
    if (p.services.contains('블랙탱크 비움')) out.add('🚽');
    if (p.services.contains('노지/차박')) out.add('🅿️');
    if (p.services.contains('공중화장실')) out.add('🚻');
    if (filter == '전체') return out;
    return [switch (filter) {
      '급수' => '💧',
      '블랙탱크 비움' => '🚽',
      '노지/차박' => '🅿️',
      '공중화장실' => '🚻',
      _ => '📍',
    }];
  }

  String _filterLabel(String e) => e == '블랙탱크 비움' ? '블랙' : e == '공중화장실' ? '화장실' : e;

  Future<void> _searchAddress() async {
    final q = search.text.trim();
    if (q.isEmpty) return;
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&countrycodes=kr&accept-language=ko&q=${Uri.encodeQueryComponent(q)}');
    try {
      final r = await http.get(uri, headers: {'User-Agent': 'CampingCarRoadmap/1.4'});
      final data = jsonDecode(r.body) as List;
      if (data.isEmpty) return _msg('검색 결과가 없습니다.');
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final x = Map<String, dynamic>.from(data[i] as Map);
              var label = '${x['display_name'] ?? ''}'
                  .replaceAll('대한민국', '')
                  .replaceAll('Republic of Korea', '')
                  .replaceAll('South Korea', '')
                  .trim();
              label = label.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');
              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(label),
                onTap: () => Navigator.pop(sheetContext, x),
              );
            },
          ),
        ),
      );
      if (selected == null) return;
      final point = LatLng(double.parse('${selected['lat']}'), double.parse('${selected['lon']}'));
      center = point;
      map.move(point, 16);
      if (mounted) setState(() {});
    } catch (_) {
      _msg('주소 검색에 실패했습니다.');
    }
  }

  Future<String> _reverseAddress(LatLng p) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}&accept-language=ko&addressdetails=1');
      final r = await http.get(uri, headers: {'User-Agent': 'CampingCarRoadmap/1.1'});
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      var s = '${j['display_name'] ?? ''}';
      s = s.replaceAll('대한민국', '').replaceAll('Republic of Korea', '').replaceAll('South Korea', '').replaceAll(RegExp(r'\bKorea\b', caseSensitive: false), '');
      return s.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '').trim();
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
    final pages = [_mapPage(), _savedPage(), _profilePage()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: '저장'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }

  Widget _mapPage() => Stack(children: [
        FlutterMap(
          mapController: map,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            onLongPress: (_, point) => _selectSpot(point),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.co.campingcarroadmap.app'),
            MarkerLayer(markers: [
              ...visiblePlaceGroups.map((group) {
                final p = group.first;
                final icons = _icons(p);
                final grouped = group.length > 1;
                return Marker(
                  point: _groupPoint(group),
                  width: grouped ? 66 : (icons.length > 2 ? 68 : 54),
                  height: grouped ? 66 : (icons.length > 2 ? 68 : 54),
                  child: GestureDetector(
                    onTap: () => _showPlaceGroup(group),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(width: 2), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)]),
                      child: grouped
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.location_on, size: 34),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(), borderRadius: BorderRadius.circular(12)),
                                    child: Text('${group.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          : GridView.count(
                              crossAxisCount: icons.length > 1 ? 2 : 1,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: icons.take(4).map((e) => Center(child: Text(e, style: const TextStyle(fontSize: 18)))).toList(),
                            ),
                    ),
                  ),
                );
              }),
              if (selectedSpot != null)
                Marker(
                  point: selectedSpot!,
                  width: 104,
                  height: 78,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                        child: const Text('등록 위치', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Icon(Icons.location_pin, color: Colors.red, size: 48),
                    ],
                  ),
                ),
            ]),
          ],
        ),
        Positioned(top: 10, left: 10, right: 10, child: Column(children: [
          Material(elevation: 3, borderRadius: BorderRadius.circular(12), child: Row(children: [
            Expanded(child: TextField(controller: search, onSubmitted: (_) => _searchAddress(), decoration: const InputDecoration(hintText: '지역명 또는 주소 검색', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14)))),
            IconButton(onPressed: _searchAddress, icon: const Icon(Icons.search)),
          ])),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: serviceFilters.map((e) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(label: Text(_filterLabel(e)), selected: filter == e, onSelected: (_) => setState(() => filter = e)),
          )).toList())),
        ])),
        if (selectedSpot != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 86,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.location_pin, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('선택 위치  ${selectedSpot!.latitude.toStringAsFixed(6)}, ${selectedSpot!.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12))),
                  TextButton(onPressed: () => setState(() => selectedSpot = null), child: const Text('취소')),
                ]),
              ),
            ),
          ),
        Positioned(right: 14, bottom: 18, child: Column(children: [
          FloatingActionButton.small(heroTag: 'loc', onPressed: _locate, child: const Icon(Icons.my_location)),
          const SizedBox(height: 10),
          FloatingActionButton.extended(heroTag: 'add', onPressed: () {
            if (selectedSpot == null) {
              _msg('지도에서 등록할 정확한 위치를 길게 눌러 빨간 핀을 먼저 찍어주세요.');
              return;
            }
            _openAddPlace(selectedSpot!);
          }, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('장소등록')),
        ])),
      ]);

  Widget _savedPage() {
    final allRows = places.where((p) => saved.contains(p.id)).toList();
    final rows = savedFilter == '전체' ? allRows : allRows.where((p) => p.services.contains(savedFilter)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('저장한 장소')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: serviceFilters.map((e) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_filterLabel(e)),
                selected: savedFilter == e,
                onSelected: (_) => setState(() => savedFilter = e),
              ),
            )).toList()),
          ),
        ),
        Expanded(
          child: allRows.isEmpty
              ? const Center(child: Text('저장한 장소가 없습니다.'))
              : rows.isEmpty
                  ? Center(child: Text('${_filterLabel(savedFilter)} 종류로 저장한 장소가 없습니다.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final p = rows[i];
                        return ListTile(
                          leading: Text(_iconsForSaved(p).join(), style: const TextStyle(fontSize: 20)),
                          title: Text(p.name),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.address),
                            const SizedBox(height: 2),
                            Text(p.services.join(' · '), style: Theme.of(context).textTheme.bodySmall),
                          ]),
                          onTap: () {
                            setState(() => tab = 0);
                            Future.delayed(const Duration(milliseconds: 150), () {
                              map.move(LatLng(p.latitude, p.longitude), 17);
                              Future.delayed(const Duration(milliseconds: 180), () => _showPlace(p));
                            });
                          },
                          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () async {
                            saved.remove(p.id);
                            await widget.data.saveSavedIds(saved);
                            if (mounted) setState(() {});
                          }),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  List<String> _iconsForSaved(Place p) {
    final out = <String>[];
    if (p.services.contains('급수')) out.add('💧');
    if (p.services.contains('블랙탱크 비움')) out.add('🚽');
    if (p.services.contains('노지/차박')) out.add('🅿️');
    if (p.services.contains('공중화장실')) out.add('🚻');
    return out.isEmpty ? ['📍'] : out;
  }

  Widget _profilePage() => Scaffold(
        appBar: AppBar(title: const Text('내정보'), actions: [IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout))]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(widget.user.userId),
            subtitle: Text(widget.user.isAdministrator ? '🔐 관리자 계정' : '${widget.user.phone}${widget.user.phoneVerified ? ' · 인증완료' : ''}'),
          )),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _passwordGate, child: const Text('개인정보 변경')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _vehicleDialog, child: const Text('차량정보 변경')),
          const SizedBox(height: 18),
          const Divider(),
          TextButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('회원탈퇴'),
          ),
        ]),
      );

  Future<void> _passwordGate() async {
    final c = TextEditingController();
    final entered = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('비밀번호 확인'),
      content: TextField(controller: c, obscureText: true, autofocus: true, onSubmitted: (_) => Navigator.pop(context, c.text), decoration: const InputDecoration(labelText: '현재 비밀번호')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('확인'))],
    ));
    if (entered == null) return;
    final ok = await widget.auth.reauthenticatePassword(entered);
    if (!ok) return _msg('비밀번호가 일치하지 않습니다.');
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('개인정보 변경'),
      content: const Text('휴대폰 번호 변경은 보안을 위해 새 번호 SMS 재인증 절차로 처리합니다. 정식 서버에서는 profiles와 Supabase Auth에 함께 반영됩니다.'),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
    ));
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('회원탈퇴'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('탈퇴하면 계정과 등록한 장소·사진·리뷰·즐겨찾기가 삭제되며 복구할 수 없습니다.'),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: '현재 비밀번호')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('탈퇴 진행')),
      ],
    ));
    if (confirmed != true) return;
    final ok = await widget.auth.reauthenticatePassword(password.text);
    if (!ok) return _msg('비밀번호가 일치하지 않습니다.');
    final finalConfirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('정말 탈퇴할까요?'),
      content: const Text('이 작업은 되돌릴 수 없습니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('예, 탈퇴합니다')),
      ],
    ));
    if (finalConfirm != true) return;
    try {
      await widget.auth.deleteAccount();
      if (!mounted) return;
      await widget.onLogout();
    } catch (e) {
      _msg('회원탈퇴에 실패했습니다: $e');
    }
  }

  Future<void> _vehicleDialog() async {
    String status = widget.user.vehicleStatus.isEmpty ? 'planned' : widget.user.vehicleStatus;
    String sanitation = widget.user.sanitationType;
    final name = TextEditingController(text: widget.user.vehicleName);
    final height = TextEditingController(text: widget.user.vehicleHeightMm?.toString() ?? '');
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('차량정보'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<String>(value: 'planned', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('구매예정')),
        RadioListTile<String>(value: 'owned', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('보유중')),
        if (status == 'owned') ...[
          TextField(controller: name, decoration: const InputDecoration(labelText: '차량명/모델')),
          TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '차량 높이(mm)')),
          const SizedBox(height: 10),
          ...['블랙탱크', '그레이탱크', '카트리지'].map((e) => RadioListTile<String>(value: e, groupValue: sanitation, onChanged: (v) => setS(() => sanitation = v!), title: Text(e))),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () async {
          if (status == 'owned' && sanitation.isEmpty) return _msg('위생설비를 선택해주세요.');
          final u = await widget.auth.updateVehicle(status: status, name: name.text.trim(), heightMm: int.tryParse(height.text), sanitation: sanitation);
          widget.onUserChanged(u);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('저장')),
      ],
    )));
  }

  Future<void> _openAddPlace(LatLng spot) async {
    final name = TextEditingController();
    final hours = TextEditingController();
    final maxHeight = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final prices = <String, TextEditingController>{for (final s in ['급수', '블랙탱크 비움', '노지/차박', '공중화장실']) s: TextEditingController()};
    final selected = <String>{};
    final photos = <XFile>[];
    String reservation = '예약불필요';
    final address = TextEditingController(text: await _reverseAddress(spot));

    if (!mounted) return;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('새 장소 등록'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.location_pin, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('지도에서 찍은 위치\n${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12))),
          ]),
        ),
        TextField(controller: name, decoration: const InputDecoration(labelText: '장소명')),
        TextField(controller: address, decoration: const InputDecoration(labelText: '주소')),
        const SizedBox(height: 10),
        ...prices.entries.map((e) => Row(children: [
          Checkbox(value: selected.contains(e.key), onChanged: (v) => setS(() {
            if (v == true) { selected.add(e.key); } else { selected.remove(e.key); e.value.clear(); }
          })),
          Expanded(flex: 2, child: Text(e.key == '블랙탱크 비움' ? '블랙탱크' : e.key)),
          Expanded(flex: 3, child: TextField(controller: e.value, enabled: selected.contains(e.key), decoration: const InputDecoration(hintText: '금액 / 무료'))),
        ])),
        TextField(controller: hours, decoration: const InputDecoration(labelText: '운영시간')),
        DropdownButtonFormField<String>(initialValue: reservation, items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => reservation = v!), decoration: const InputDecoration(labelText: '예약 여부')),
        TextField(controller: maxHeight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '진입 최대 높이(mm)')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처')),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6);
            setS(() { photos.clear(); photos.addAll(picked); });
          }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))),
        ]),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: loading ? null : () async {
          if (name.text.trim().isEmpty || selected.isEmpty) return _msg('장소명과 서비스 항목을 입력해주세요.');
          for (final s in selected) {
            if (prices[s]!.text.trim().isEmpty) return _msg('$s 금액을 입력해주세요. 무료인 경우 무료라고 입력해주세요.');
          }
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
              maxHeightMm: int.tryParse(maxHeight.text),
              phone: phone.text.trim(),
              note: note.text.trim(),
              ownerId: widget.user.authId.isEmpty ? widget.user.userId : widget.user.authId,
            );
            await widget.data.addPlace(p);
            p.photoUrls = await widget.data.uploadPlacePhotos(p.id, photos.map((e) => File(e.path)).toList());
            places.insert(0, p);
            selectedSpot = null;
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) setState(() {});
          } catch (e) {
            _msg('장소 등록에 실패했습니다: $e');
          } finally {
            if (mounted) setState(() => loading = false);
          }
        }, child: const Text('등록')),
      ],
    )));
  }

  Future<void> _showPlace(Place p) async {
    final reviews = await widget.data.reviews(p.id);
    if (!mounted) return;
    await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .68,
      minChildSize: .42,
      maxChildSize: .92,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(p.services.join(' · ')),
        if (p.address.isNotEmpty) Text(p.address),
        if (p.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: p.photoUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p.photoUrls[i], width: 210, fit: BoxFit.cover)))),
        ],
        const SizedBox(height: 12),
        if (p.hours.isNotEmpty) Text('운영시간: ${p.hours}'),
        if (p.reservation.isNotEmpty) Text('예약: ${p.reservation}'),
        if (p.phone.isNotEmpty) Text('문의연락처: ${p.phone}'),
        if (p.maxHeightMm != null) Text('진입 최대 높이: ${p.maxHeightMm}mm'),
        if (p.maxHeightMm != null && widget.user.vehicleHeightMm != null) _heightCompatibility(p),
        if (p.note.isNotEmpty) Text('이용방법/주의사항: ${p.note}'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            if (saved.contains(p.id)) { saved.remove(p.id); } else { saved.add(p.id); }
            await widget.data.saveSavedIds(saved);
            if (mounted) setState(() {});
          }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),
        ]),
        if (widget.user.isAdministrator) ...[
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () { Navigator.pop(ctx); _adminEditPlace(p); }, icon: const Icon(Icons.admin_panel_settings_outlined), label: const Text('정보 수정 · 관리자 전용')),
        ],
        const Divider(height: 28),
        const Text('검증 리뷰', style: TextStyle(fontWeight: FontWeight.bold)),
        if (reviews.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('아직 검증 리뷰가 없습니다.')),
        ...reviews.map(_reviewTile),
      ]),
    ));
  }

  Widget _heightCompatibility(Place p) {
    final vehicle = widget.user.vehicleHeightMm!;
    final limit = p.maxHeightMm!;
    final margin = limit - vehicle;
    final (icon, label) = margin < 0
        ? ('⛔', '진입불가')
        : margin < 100
            ? ('⚠️', '진입주의')
            : ('✅', '진입가능');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$icon 내 차량 ${vehicle}mm · $label (여유 ${margin}mm)'),
    );
  }

  Widget _reviewTile(PlaceReview r) {
    final label = switch (r.status) { 'ok' => '이용가능', 'change' => '변경', 'bad' => '이용불가', _ => r.status };
    return ListTile(contentPadding: EdgeInsets.zero, leading: Text(switch (r.status) { 'ok' => '✅', 'change' => '⚠️', 'bad' => '⛔', _ => '📝' }), title: Text('$label · ${r.authorName}'), subtitle: Text(r.body.isEmpty ? '내용 없음' : r.body));
  }

  Future<void> _openReview(Place p) async {
    String status = 'ok';
    final body = TextEditingController();
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('검증리뷰'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<String>(value: 'ok', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('이용가능')),
        RadioListTile<String>(value: 'change', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('변경')),
        RadioListTile<String>(value: 'bad', groupValue: status, onChanged: (v) => setS(() => status = v!), title: const Text('이용불가')),
        TextField(controller: body, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: '짧은 리뷰')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')), FilledButton(onPressed: () async {
        await widget.data.addReview(placeId: p.id, status: status, body: body.text);
        if (ctx.mounted) Navigator.pop(ctx);
        _msg('검증리뷰가 등록되었습니다.');
        _load();
      }, child: const Text('등록'))],
    )));
  }

  Future<void> _adminEditPlace(Place p) async {
    if (!widget.user.isAdministrator) return _msg('관리자만 수정할 수 있습니다.');
    final name = TextEditingController(text: p.name);
    final address = TextEditingController(text: p.address);
    final hours = TextEditingController(text: p.hours);
    final maxHeight = TextEditingController(text: p.maxHeightMm?.toString() ?? '');
    final phone = TextEditingController(text: p.phone);
    final note = TextEditingController(text: p.note);
    final serviceNames = ['급수', '블랙탱크 비움', '노지/차박', '공중화장실'];
    final selected = p.services.toSet();
    final prices = <String, TextEditingController>{
      for (final service in serviceNames) service: TextEditingController(text: p.prices[service] ?? ''),
    };
    String reservation = p.reservation.isEmpty ? '예약불필요' : p.reservation;

    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('장소 정보 수정'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '장소명')),
        TextField(controller: address, decoration: const InputDecoration(labelText: '주소')),
        const SizedBox(height: 10),
        ...serviceNames.map((service) => Row(children: [
          Checkbox(value: selected.contains(service), onChanged: (v) => setS(() {
            if (v == true) {
              selected.add(service);
            } else {
              selected.remove(service);
              prices[service]!.clear();
            }
          })),
          Expanded(flex: 2, child: Text(service == '블랙탱크 비움' ? '블랙탱크' : service)),
          Expanded(flex: 3, child: TextField(
            controller: prices[service],
            enabled: selected.contains(service),
            decoration: const InputDecoration(hintText: '금액 / 무료'),
          )),
        ])),
        TextField(controller: hours, decoration: const InputDecoration(labelText: '운영시간')),
        DropdownButtonFormField<String>(
          initialValue: ['예약불필요', '예약필수', '전화문의'].contains(reservation) ? reservation : '예약불필요',
          items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setS(() => reservation = v!),
          decoration: const InputDecoration(labelText: '예약 여부'),
        ),
        TextField(controller: maxHeight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '진입 최대 높이(mm)')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처')),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty || selected.isEmpty) return _msg('장소명과 서비스 항목을 입력해주세요.');
          for (final service in selected) {
            if (prices[service]!.text.trim().isEmpty) return _msg('$service 금액을 입력해주세요. 무료인 경우 무료라고 입력해주세요.');
          }
          p.name = name.text.trim();
          p.address = address.text.trim();
          p.services = selected.toList();
          p.prices = {for (final service in selected) service: prices[service]!.text.trim()};
          p.hours = hours.text.trim();
          p.reservation = reservation;
          p.maxHeightMm = int.tryParse(maxHeight.text);
          p.phone = phone.text.trim();
          p.note = note.text.trim();
          try {
            await widget.data.updatePlace(p);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) setState(() {});
            _msg('장소 정보를 수정했습니다.');
          } catch (_) {
            _msg('관리자 권한이 없거나 수정에 실패했습니다.');
          }
        }, child: const Text('수정 저장')),
      ],
    )));
  }
}
