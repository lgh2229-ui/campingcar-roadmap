from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text()
old_visible = """  List<Place> get visiblePlaces {\n    final rows = filter == '전체' ? places : places.where((p) => p.services.contains(filter)).toList();\n    return rows;\n  }\n"""
new_visible = """  List<Place> get visiblePlaces {\n    final approved = places.where((p) => p.isApproved).toList();\n    final rows = filter == '전체' ? approved : approved.where((p) => p.services.contains(filter)).toList();\n    return rows;\n  }\n"""
if old_visible in s:
    s = s.replace(old_visible, new_visible, 1)

old_save = """            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n"""
new_save = """            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              setState(() { if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); } });\n              try { await widget.data.saveSavedIds(saved); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { if (mounted) { setState(() { if (wasSaved) { saved.add(p.id); } else { saved.remove(p.id); } }); } _msg('저장 처리에 실패했습니다: $e'); }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n"""
if old_save in s:
    s = s.replace(old_save, new_save, 1)

# Add external map launcher import and helper.
if "package:url_launcher/url_launcher.dart" not in s:
    s = s.replace("import 'package:uuid/uuid.dart';\n", "import 'package:uuid/uuid.dart';\nimport 'package:url_launcher/url_launcher.dart';\n", 1)

anchor = "  Future<void> _showPlace(Place p) async {\n"
helper = """  Future<void> _openExternalMap(Place p) async {\n    final choice = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [\n      ListTile(leading: const Icon(Icons.navigation), title: const Text('TMAP으로 열기'), onTap: () => Navigator.pop(ctx, 'tmap')),\n      ListTile(leading: const Icon(Icons.map), title: const Text('카카오맵으로 열기'), onTap: () => Navigator.pop(ctx, 'kakao')),\n    ])));\n    if (choice == null) return;\n    final name = Uri.encodeComponent(p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'), ''));\n    final uri = choice == 'tmap'\n        ? Uri.parse('tmap://route?goalname=$name&goalx=${p.longitude}&goaly=${p.latitude}')\n        : Uri.parse('kakaomap://look?p=${p.latitude},${p.longitude}');\n    try {\n      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);\n      if (!ok) _msg(choice == 'tmap' ? 'TMAP 앱을 실행할 수 없습니다.' : '카카오맵 앱을 실행할 수 없습니다.');\n    } catch (_) {\n      _msg(choice == 'tmap' ? 'TMAP 앱이 설치되어 있는지 확인해주세요.' : '카카오맵 앱이 설치되어 있는지 확인해주세요.');\n    }\n  }\n\n"""
if helper not in s and anchor in s:
    s = s.replace(anchor, helper + anchor, 1)

old_address = "        if (p.address.isNotEmpty) Text(p.address),\n"
new_address = "        if (p.address.isNotEmpty) InkWell(onTap: () => _openExternalMap(p), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.directions, size: 18), const SizedBox(width: 6), Expanded(child: Text(p.address, style: const TextStyle(decoration: TextDecoration.underline)))]))),\n"
if old_address in s:
    s = s.replace(old_address, new_address, 1)
p.write_text(s)

# The admin detail screen was redesigned; only apply the old SafeArea patch when its old pattern still exists.
p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text()
old_body = """      body: Column(children: [\n"""
old_end = """      ]),\n    );\n  }\n}\n"""
if old_body in s and old_end in s:
    s = s.replace(old_body, """      body: SafeArea(\n        bottom: true,\n        child: Column(children: [\n""", 1)
    s = s.replace(old_end, """        ]),\n      ),\n    );\n  }\n}\n""", 1)
p.write_text(s)
