from pathlib import Path
p=Path('lib/screens/home_screen.dart');s=p.read_text(encoding='utf-8')
if "import 'feedback_screen.dart';" not in s:
    s=s.replace("import 'vehicle_market_screen.dart';", "import 'vehicle_market_screen.dart';\nimport 'feedback_screen.dart';\nimport 'admin_management_screen.dart';")
anchor="          OutlinedButton(onPressed: _vehicleDialog, child: const Text('차량정보 변경')),"
if anchor in s and "앱 이용 / 의견 제출" not in s:
    s=s.replace(anchor,anchor+"\n          const SizedBox(height: 8),\n          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())), icon: const Icon(Icons.feedback_outlined), label: const Text('앱 이용 / 의견 제출')),\n          if (widget.user.isAdministrator) ...[\n            const SizedBox(height: 8),\n            FilledButton.tonalIcon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminManagementScreen())), icon: const Icon(Icons.admin_panel_settings), label: const Text('관리자 통합관리')),\n          ],")
# underline both section headings everywhere they occur
s=s.replace("const Text('이용안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))","const Text('이용안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))")
s=s.replace("const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))","const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))")
# Requested final order: 이용안내 first, then spacing, then camper service.
# In the generated detail block service is directly before the 이용안내 heading; remove it there and insert before reviews/end after note area.
needle="        _serviceAvailability(p),\n        const Text('이용안내',"
if needle in s:
    s=s.replace(needle,"        const Text('이용안내',",1)
    candidates=[
      "        if (p.note.isNotEmpty) Text('이용방법/주의사항: ${p.note}'),",
      "        if (p.note.isNotEmpty) Text('이용방법 / 주의사항: ${p.note}'),"
    ]
    for a in candidates:
        if a in s:
            s=s.replace(a,a+"\n        const SizedBox(height: 16),\n        _serviceAvailability(p),",1);break
p.write_text(s,encoding='utf-8');print('market support/profile/admin/detail layout applied')
