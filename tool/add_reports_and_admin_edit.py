from pathlib import Path

# Repository interface
p = Path('lib/repositories/app_data_repository.dart')
s = p.read_text()
needle = "  Future<void> addReviewComment({required String reviewId, required String body});\n"
insert = needle + "  Future<void> addPlaceReport({required String placeId, required String reportType, required String body});\n  Future<List<Map<String, dynamic>>> pendingPlaceReports();\n  Future<void> completePlaceReport(String reportId);\n"
if "pendingPlaceReports" not in s:
    if needle not in s: raise SystemExit('app_data_repository insertion point not found')
    s = s.replace(needle, insert, 1)
p.write_text(s)

# Supabase implementation
p = Path('lib/repositories/supabase_repository.dart')
s = p.read_text()
needle = "  @override\n  Future<void> addReviewComment({required String reviewId, required String body}) async {\n    if (body.trim().isEmpty) throw Exception('댓글 내용을 입력해주세요.');\n    await client.from('review_comments').insert({'review_id': reviewId, 'author_id': _uid, 'body': body.trim()});\n  }\n"
insert = needle + "\n  @override\n  Future<void> addPlaceReport({required String placeId, required String reportType, required String body}) async {\n    if (!['change', 'bad'].contains(reportType)) throw Exception('신고 유형이 올바르지 않습니다.');\n    await client.from('place_reports').insert({'place_id': placeId, 'reporter_id': _uid, 'report_type': reportType, 'body': body.trim()});\n  }\n\n  @override\n  Future<List<Map<String, dynamic>>> pendingPlaceReports() async {\n    final rows = await client.from('place_reports').select('id, place_id, report_type, body, created_at').eq('handled', false).order('created_at', ascending: false);\n    final out = <Map<String, dynamic>>[];\n    for (final raw in rows as List) {\n      final r = Map<String, dynamic>.from(raw as Map);\n      final placeRows = await client.from('places_view').select().eq('id', r['place_id']).limit(1);\n      if ((placeRows as List).isNotEmpty) r['place'] = Map<String, dynamic>.from(placeRows.first as Map);\n      out.add(r);\n    }\n    return out;\n  }\n\n  @override\n  Future<void> completePlaceReport(String reportId) async {\n    await client.from('place_reports').update({'handled': true, 'handled_by': _uid, 'handled_at': DateTime.now().toIso8601String()}).eq('id', reportId);\n  }\n"
if "pendingPlaceReports" not in s:
    if needle not in s: raise SystemExit('supabase insertion point not found')
    s = s.replace(needle, insert, 1)
p.write_text(s)

# Local repository implementation and stop creating admin tasks from reviews
p = Path('lib/repositories/local_repository.dart')
s = p.read_text()
if "_reportsKey" not in s:
    s = s.replace("  static const _tasksKey = 'roadmap_admin_review_tasks_flutter';\n", "  static const _tasksKey = 'roadmap_admin_review_tasks_flutter';\n  static const _reportsKey = 'roadmap_place_reports_flutter';\n", 1)
old_task = """    if (status == 'change' || status == 'bad') {\n      final tasks = p.getString(_tasksKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_tasksKey)!) as List);\n      tasks.add({'id': 'task_$id', 'review_id': id, 'place_id': placeId, 'reason': status == 'bad' ? '이용불가 리뷰' : '변경 리뷰', 'handled': false, 'created_at': DateTime.now().toIso8601String()});\n      await p.setString(_tasksKey, jsonEncode(tasks));\n    }\n"""
s = s.replace(old_task, "", 1)
needle = "  @override\n  Future<void> addReviewComment({required String reviewId, required String body}) async {\n    final p = await _prefs; final list = p.getString(_commentsKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_commentsKey)!) as List);\n    final uid = await sessionUserId() ?? ''; final me = (await users()).where((u) => u.userId == uid).firstOrNull;\n    list.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'review_id': reviewId, 'author_id': uid, 'author_name': me?.displayName ?? uid, 'body': body.trim(), 'created_at': DateTime.now().toIso8601String()});\n    await p.setString(_commentsKey, jsonEncode(list));\n  }\n"
insert = needle + "\n  @override\n  Future<void> addPlaceReport({required String placeId, required String reportType, required String body}) async {\n    final p = await _prefs;\n    final list = p.getString(_reportsKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_reportsKey)!) as List);\n    list.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'place_id': placeId, 'report_type': reportType, 'body': body.trim(), 'handled': false, 'created_at': DateTime.now().toIso8601String()});\n    await p.setString(_reportsKey, jsonEncode(list));\n  }\n\n  @override\n  Future<List<Map<String, dynamic>>> pendingPlaceReports() async {\n    final p = await _prefs; final raw = p.getString(_reportsKey); if (raw == null) return [];\n    final allPlaces = await _allPlaces();\n    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).where((e) => e['handled'] != true).map((e) {\n      final place = allPlaces.where((x) => x.id == '${e['place_id']}').firstOrNull;\n      if (place != null) e['place'] = place.toJson();\n      return e;\n    }).toList();\n  }\n\n  @override\n  Future<void> completePlaceReport(String reportId) async {\n    final p = await _prefs; final raw = p.getString(_reportsKey); if (raw == null) return;\n    final list = List<dynamic>.from(jsonDecode(raw) as List); final i = list.indexWhere((e) => '${(e as Map)['id']}' == reportId);\n    if (i >= 0) { final row = Map<String, dynamic>.from(list[i] as Map); row['handled'] = true; list[i] = row; await p.setString(_reportsKey, jsonEncode(list)); }\n  }\n"
if "pendingPlaceReports" not in s:
    if needle not in s: raise SystemExit('local insertion point not found')
    s = s.replace(needle, insert, 1)
p.write_text(s)

# Home screen: report button, report dialog, admin-only direct edit button.
p = Path('lib/screens/home_screen.dart')
s = p.read_text()
old_buttons = """          Row(children: [\n            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n            const SizedBox(width: 8),\n            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n          ]),\n"""
new_buttons = """          Row(children: [\n            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n            const SizedBox(width: 8),\n            Expanded(child: FilledButton.tonalIcon(onPressed: () { Navigator.pop(ctx); _openPlaceReport(p); }, icon: const Icon(Icons.report_outlined), label: const Text('신고'))),\n          ]),\n          const SizedBox(height: 8),\n          Row(children: [\n            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n            if (widget.user.isAdministrator) ...[\n              const SizedBox(width: 8),\n              Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(ctx); _openAdminEditPlace(p); }, icon: const Icon(Icons.edit), label: const Text('수정변경'))),\n            ],\n          ]),\n"""
if old_buttons in s:
    s = s.replace(old_buttons, new_buttons, 1)
else:
    # Handles the optimistic favorite patch applied by an earlier build step.
    marker = "            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n          ]),\n"
    repl = "            Expanded(child: FilledButton.tonalIcon(onPressed: () { Navigator.pop(ctx); _openPlaceReport(p); }, icon: const Icon(Icons.report_outlined), label: const Text('신고'))),\n          ]),\n          const SizedBox(height: 8),\n          Row(children: [\n            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n            if (widget.user.isAdministrator) ...[const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(ctx); _openAdminEditPlace(p); }, icon: const Icon(Icons.edit), label: const Text('수정변경')))],\n          ]),\n"
    if marker not in s: raise SystemExit('home approved buttons insertion point not found')
    s = s.replace(marker, repl, 1)

# Remove wording that review change/bad enters admin queue.
s = s.replace("        if (status != 'ok') const Text('변경/이용불가 리뷰는 관리자 검증리뷰 확인 목록에도 자동 등록됩니다.', style: TextStyle(fontSize: 12)),\n", "")

append_marker = "  Future<void> _openReview(Place p) async {\n"
methods = r'''  Future<void> _openPlaceReport(Place p) async {
    String reportType = 'change';
    final body = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('장소 신고'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<String>(value: 'change', groupValue: reportType, onChanged: (v) => setS(() => reportType = v!), title: const Text('변경 신고')),
        RadioListTile<String>(value: 'bad', groupValue: reportType, onChanged: (v) => setS(() => reportType = v!), title: const Text('사용불가 신고')),
        TextField(controller: body, maxLength: 300, maxLines: 4, decoration: const InputDecoration(labelText: '신고 내용', hintText: '변경된 정보나 사용불가 사유를 입력해주세요.')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고 접수'))],
    )));
    if (ok != true) return;
    if (body.text.trim().isEmpty) return _msg('신고 내용을 입력해주세요.');
    try { await widget.data.addPlaceReport(placeId: p.id, reportType: reportType, body: body.text); _msg('신고가 접수되었습니다. 관리자가 확인합니다.'); } catch (e) { _msg('신고 접수에 실패했습니다: $e'); }
  }

  Future<void> _openAdminEditPlace(Place p) async {
    if (!widget.user.isAdministrator) return;
    final name = TextEditingController(text: p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'), ''));
    final address = TextEditingController(text: p.address);
    final hours = TextEditingController(text: p.hours);
    final maxHeight = TextEditingController(text: p.maxHeightMm == null ? '' : _meters(p.maxHeightMm!));
    final phone = TextEditingController(text: p.phone);
    final note = TextEditingController(text: p.note);
    final selected = p.services.toSet();
    final prices = <String, TextEditingController>{for (final x in ['급수', '블랙탱크 비움', '노지/차박', '공중화장실']) x: TextEditingController(text: p.prices[x] ?? '')};
    String reservation = p.reservation.isEmpty ? '예약불필요' : p.reservation;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('관리자 장소 수정변경'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '장소명')),
        TextField(controller: address, decoration: const InputDecoration(labelText: '주소')),
        ...prices.entries.map((e) => Row(children: [Checkbox(value: selected.contains(e.key), onChanged: (v) => setS(() { if (v == true) { selected.add(e.key); } else { selected.remove(e.key); e.value.clear(); } })), Expanded(flex: 2, child: Text(e.key)), Expanded(flex: 3, child: TextField(controller: e.value, enabled: selected.contains(e.key), decoration: const InputDecoration(hintText: '금액 / 무료')))])),
        TextField(controller: hours, decoration: const InputDecoration(labelText: '운영시간')),
        DropdownButtonFormField<String>(initialValue: reservation, items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => reservation = v ?? reservation, decoration: const InputDecoration(labelText: '예약 여부')),
        TextField(controller: maxHeight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '진입 최대 높이', suffixText: 'm')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처')),
        TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: '이용방법 / 주의사항')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('수정 저장'))],
    )));
    if (ok != true) return;
    if (name.text.trim().isEmpty || selected.isEmpty) return _msg('장소명과 서비스 항목을 입력해주세요.');
    for (final x in selected) { if (prices[x]!.text.trim().isEmpty) return _msg('$x 금액을 입력해주세요.'); }
    p.name = name.text.trim(); p.address = address.text.trim(); p.services = selected.toList(); p.prices = {for (final x in selected) x: prices[x]!.text.trim()}; p.hours = hours.text.trim(); p.reservation = reservation; p.maxHeightMm = maxHeight.text.trim().isEmpty ? null : _metersToMm(maxHeight.text); p.phone = phone.text.trim(); p.note = note.text.trim();
    try { await widget.data.updatePlace(p); await _load(); _msg('관리자 수정이 저장되었습니다.'); } catch (e) { _msg('장소 수정에 실패했습니다: $e'); }
  }

'''
if "_openPlaceReport(Place p)" not in s:
    if append_marker not in s: raise SystemExit('home method insertion point not found')
    s = s.replace(append_marker, methods + append_marker, 1)
p.write_text(s)

# Admin home: add report list and report map detail page.
p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text()
insert_point = "  @override\n  Widget build(BuildContext context) {\n"
report_method = r'''  Future<void> _openReports() async {
    setState(() => busy = true);
    List<Map<String, dynamic>> rows = [];
    try { rows = await widget.data.pendingPlaceReports(); } catch (e) { _msg('신고 목록을 불러오지 못했습니다: $e'); } finally { if (mounted) setState(() => busy = false); }
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => SafeArea(child: SizedBox(
      height: MediaQuery.of(ctx).size.height * .72,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: Row(children: [const Expanded(child: Text('신고 목록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), Chip(label: Text('${rows.length}건'))])),
        const Divider(height: 1),
        Expanded(child: rows.isEmpty ? const Center(child: Text('확인할 신고가 없습니다.')) : ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
          final r = rows[i]; final rawPlace = r['place']; final place = rawPlace is Map ? Place.fromJson(Map<String, dynamic>.from(rawPlace)) : null; final type = r['report_type'] == 'bad' ? '사용불가' : '변경';
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.report_outlined)), title: Text('[신고건/$type] ${place?.name ?? '장소'}'), subtitle: Text('${place?.address ?? ''}\n${r['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis), isThreeLine: true, trailing: const Icon(Icons.map_outlined), onTap: place == null ? null : () { Navigator.pop(ctx); Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPlaceReportScreen(report: r, place: place, data: widget.data))).then((_) => setState(() {})); });
        })),
      ]),
    )));
  }

'''
if "Future<void> _openReports()" not in s:
    if insert_point not in s: raise SystemExit('admin method insertion point not found')
    s = s.replace(insert_point, report_method + insert_point, 1)

old_pos = """      Positioned(\n        top: MediaQuery.of(context).padding.top + 12,\n        right: 12,\n        child: SafeArea(\n          child: FloatingActionButton.extended(\n            heroTag: 'adminApprovalList',\n            onPressed: busy ? null : _openPending,\n            icon: busy\n                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))\n                : const Icon(Icons.admin_panel_settings),\n            label: const Text('승인목록'),\n          ),\n        ),\n      ),\n"""
new_pos = """      Positioned(\n        top: MediaQuery.of(context).padding.top + 12,\n        right: 12,\n        child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [\n          FloatingActionButton.extended(heroTag: 'adminApprovalList', onPressed: busy ? null : _openPending, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.admin_panel_settings), label: const Text('승인목록')),\n          const SizedBox(height: 8),\n          FloatingActionButton.extended(heroTag: 'adminReportList', onPressed: busy ? null : _openReports, icon: const Icon(Icons.report_outlined), label: const Text('신고목록')),\n        ])),\n      ),\n"""
if old_pos in s: s = s.replace(old_pos, new_pos, 1)
elif "adminReportList" not in s: raise SystemExit('admin FAB insertion point not found')

# Add report detail screen before AdminPlaceReviewScreen.
class_marker = "class AdminPlaceReviewScreen extends StatefulWidget {\n"
report_class = r'''class AdminPlaceReportScreen extends StatefulWidget {
  const AdminPlaceReportScreen({super.key, required this.report, required this.place, required this.data});
  final Map<String, dynamic> report;
  final Place place;
  final AppDataRepository data;
  @override State<AdminPlaceReportScreen> createState() => _AdminPlaceReportScreenState();
}

class _AdminPlaceReportScreenState extends State<AdminPlaceReportScreen> {
  bool saving = false;
  Future<void> _complete() async {
    setState(() => saving = true);
    try { await widget.data.completePlaceReport('${widget.report['id']}'); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고 확인을 완료했습니다.'))); Navigator.pop(context, true); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리에 실패했습니다: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) {
    final p = widget.place; final point = LatLng(p.latitude, p.longitude); final type = widget.report['report_type'] == 'bad' ? '사용불가 신고' : '변경 신고';
    return Scaffold(appBar: AppBar(title: Text('신고건 · $type')), body: SafeArea(child: Column(children: [
      Expanded(flex: 5, child: FlutterMap(options: MapOptions(initialCenter: point, initialZoom: 17), children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.co.campingcarroadmap.app'), MarkerLayer(markers: [Marker(point: point, width: 70, height: 70, alignment: Alignment.topCenter, child: const Icon(Icons.location_pin, size: 58, color: Colors.red))])])),
      Expanded(flex: 4, child: ListView(padding: const EdgeInsets.all(18), children: [Text(p.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), if (p.address.isNotEmpty) Text(p.address), const SizedBox(height: 12), Text(type, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('${widget.report['body'] ?? ''}'), const SizedBox(height: 18), FilledButton.icon(onPressed: saving ? null : _complete, icon: const Icon(Icons.check), label: const Text('신고 확인완료'))]))
    ])));
  }
}

'''
if "class AdminPlaceReportScreen" not in s:
    if class_marker not in s: raise SystemExit('admin report class insertion point not found')
    s = s.replace(class_marker, report_class + class_marker, 1)
p.write_text(s)
