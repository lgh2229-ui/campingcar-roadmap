import 'package:flutter/material.dart';
import '../models/admin_review_task.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../repositories/app_data_repository.dart';
import '../repositories/auth_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.user, required this.auth, required this.data, required this.onLogout});
  final AppUser user;
  final AuthRepository auth;
  final AppDataRepository data;
  final Future<void> Function() onLogout;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Place> pending = [];
  List<AdminReviewTask> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      pending = await widget.data.pendingPlaces();
      tasks = await widget.data.adminReviewTasks();
    } catch (e) {
      if (mounted) _msg('관리자 데이터를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _editPlace(Place p) async {
    final name = TextEditingController(text: p.name.replaceFirst(RegExp(r'^\[(승인 대기|승인 반려)\]\s*'), ''));
    final address = TextEditingController(text: p.address);
    final hours = TextEditingController(text: p.hours);
    final height = TextEditingController(text: p.maxHeightMm == null ? '' : (p.maxHeightMm! / 1000).toStringAsFixed(2));
    final phone = TextEditingController(text: p.phone);
    final note = TextEditingController(text: p.note);
    final services = ['급수', '블랙탱크 비움', '노지/차박', '공중화장실'];
    final selected = p.services.toSet();
    final prices = <String, TextEditingController>{for (final s in services) s: TextEditingController(text: p.prices[s] ?? '')};
    String reservation = p.reservation.isEmpty ? '예약불필요' : p.reservation;

    final save = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('등록 장소 수정'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '장소명')),
        TextField(controller: address, decoration: const InputDecoration(labelText: '주소')),
        const SizedBox(height: 8),
        ...services.map((s) => Row(children: [
          Checkbox(value: selected.contains(s), onChanged: (v) => setS(() { if (v == true) { selected.add(s); } else { selected.remove(s); } })),
          Expanded(flex: 2, child: Text(s)),
          Expanded(flex: 3, child: TextField(controller: prices[s], enabled: selected.contains(s), decoration: const InputDecoration(hintText: '금액 / 무료'))),
        ])),
        TextField(controller: hours, decoration: const InputDecoration(labelText: '운영시간')),
        DropdownButtonFormField<String>(initialValue: ['예약불필요','예약필수','전화문의'].contains(reservation) ? reservation : '예약불필요', items: ['예약불필요','예약필수','전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => reservation = v ?? reservation, decoration: const InputDecoration(labelText: '예약 여부')),
        TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '진입 최대 높이', suffixText: 'm')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처')),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장'))],
    )));
    if (save != true) return;
    if (name.text.trim().isEmpty || selected.isEmpty) return _msg('장소명과 서비스 항목을 확인해주세요.');
    p.name = name.text.trim();
    p.address = address.text.trim();
    p.services = selected.toList();
    p.prices = {for (final s in selected) s: prices[s]!.text.trim()};
    p.hours = hours.text.trim();
    p.reservation = reservation;
    final meters = double.tryParse(height.text.trim());
    p.maxHeightMm = meters == null ? null : (meters * 1000).round();
    p.phone = phone.text.trim();
    p.note = note.text.trim();
    try {
      await widget.data.updatePlace(p);
      _msg('장소 정보를 수정했습니다.');
      await _load();
    } catch (e) {
      _msg('장소 수정에 실패했습니다: $e');
    }
  }

  Future<void> _approve(Place p) async {
    await widget.data.approvePlace(p.id);
    _msg('승인했습니다. 이제 일반 사용자에게 공개됩니다.');
    await _load();
  }

  Future<void> _reject(Place p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('등록 반려'), content: Text('${p.name}\n이 장소 등록을 반려할까요?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('반려'))]));
    if (ok != true) return;
    await widget.data.rejectPlace(p.id);
    _msg('반려했습니다.');
    await _load();
  }

  Future<void> _completeTask(AdminReviewTask task) async {
    await widget.data.completeAdminReviewTask(task.id);
    _msg('검증리뷰 확인 완료 처리했습니다.');
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('관리자 페이지 · ${widget.user.displayName}'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh)), IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('관리자 모드'), subtitle: Text('아이디 ${widget.user.userId} · 닉네임 ${widget.user.displayName}'))),
              const SizedBox(height: 16),
              Text('장소 승인 대기 ${pending.length}건', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (pending.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('승인 대기 장소가 없습니다.'))),
              ...pending.map((p) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                if (p.address.isNotEmpty) Text(p.address),
                Text(p.services.join(' · ')),
                if (p.maxHeightMm != null) Text('진입 최대 높이 ${(p.maxHeightMm! / 1000).toStringAsFixed(2)}m'),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _editPlace(p), icon: const Icon(Icons.edit), label: const Text('수정'))), const SizedBox(width: 6), Expanded(child: FilledButton.icon(onPressed: () => _approve(p), icon: const Icon(Icons.check), label: const Text('승인'))), const SizedBox(width: 6), Expanded(child: TextButton(onPressed: () => _reject(p), child: const Text('반려')))]),
              ])))),
              const SizedBox(height: 24),
              Text('검증리뷰 확인 사항 ${tasks.length}건', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (tasks.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('확인할 변경/이용불가 리뷰가 없습니다.'))),
              ...tasks.map((t) => Card(child: ListTile(
                leading: const Icon(Icons.report_problem_outlined),
                title: Text(t.reason),
                subtitle: Text('장소 ${t.placeId}\n${t.createdAt.toLocal()}'),
                isThreeLine: true,
                trailing: FilledButton.tonal(onPressed: () => _completeTask(t), child: const Text('확인 완료')),
              ))),
            ]),
          ),
  );
}
