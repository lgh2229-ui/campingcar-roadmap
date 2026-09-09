from pathlib import Path

# Home map: show approved places only. Keep pending/rejected records in My Places, not on the public map.
p = Path('lib/screens/home_screen.dart')
s = p.read_text()
old_visible = """  List<Place> get visiblePlaces {\n    final rows = filter == '전체' ? places : places.where((p) => p.services.contains(filter)).toList();\n    return rows;\n  }\n"""
new_visible = """  List<Place> get visiblePlaces {\n    final approved = places.where((p) => p.isApproved).toList();\n    final rows = filter == '전체' ? approved : approved.where((p) => p.services.contains(filter)).toList();\n    return rows;\n  }\n"""
if old_visible not in s:
    raise SystemExit('visiblePlaces pattern not found')
s = s.replace(old_visible, new_visible, 1)

# Favorite button: update star immediately, persist in background, rollback if persistence fails.
old_save = """            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n"""
new_save = """            Expanded(child: FilledButton.tonalIcon(onPressed: () async {\n              final wasSaved = saved.contains(p.id);\n              setState(() {\n                if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              });\n              try {\n                await widget.data.saveSavedIds(saved);\n                _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.');\n              } catch (e) {\n                if (mounted) {\n                  setState(() {\n                    if (wasSaved) { saved.add(p.id); } else { saved.remove(p.id); }\n                  });\n                }\n                _msg('저장 처리에 실패했습니다: $e');\n              }\n            }, icon: Icon(saved.contains(p.id) ? Icons.star : Icons.star_border), label: Text(saved.contains(p.id) ? '저장됨' : '저장'))),\n"""
if old_save not in s:
    raise SystemExit('save button pattern not found')
s = s.replace(old_save, new_save, 1)
p.write_text(s)

# Admin review detail: keep approve/reject controls above Android system navigation area.
p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text()
old_body = """      body: Column(children: [\n"""
new_body = """      body: SafeArea(\n        bottom: true,\n        child: Column(children: [\n"""
if old_body not in s:
    raise SystemExit('admin body pattern not found')
s = s.replace(old_body, new_body, 1)
old_end = """      ]),\n    );\n  }\n}\n"""
new_end = """        ]),\n      ),\n    );\n  }\n}\n"""
if old_end not in s:
    raise SystemExit('admin body closing pattern not found')
s = s.replace(old_end, new_end, 1)
p.write_text(s)
