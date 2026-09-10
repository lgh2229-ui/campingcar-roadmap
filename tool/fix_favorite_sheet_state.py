from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text()

old_start = """    await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => DraggableScrollableSheet(\n      expand: false,\n"""
new_start = """    await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => DraggableScrollableSheet(\n      expand: false,\n"""
if old_start not in s:
    raise SystemExit('place sheet start pattern not found')
s = s.replace(old_start, new_start, 1)

# The previous optimistic favorite patch calls only the parent setState. The bottom sheet is a separate route,
# so rebuild the sheet immediately as well.
old_favorite = """              setState(() {\n                if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              });\n"""
new_favorite = """              setSheetState(() {\n                if (wasSaved) { saved.remove(p.id); } else { saved.add(p.id); }\n              });\n              if (mounted) setState(() {});\n"""
if old_favorite not in s:
    raise SystemExit('optimistic favorite block not found')
s = s.replace(old_favorite, new_favorite, 1)

old_rollback = """                  setState(() {\n                    if (wasSaved) { saved.add(p.id); } else { saved.remove(p.id); }\n                  });\n"""
new_rollback = """                  setSheetState(() {\n                    if (wasSaved) { saved.add(p.id); } else { saved.remove(p.id); }\n                  });\n                  setState(() {});\n"""
if old_rollback not in s:
    raise SystemExit('favorite rollback block not found')
s = s.replace(old_rollback, new_rollback, 1)

old_end = """      ]),\n    ));\n  }\n\n  Widget _heightCompatibility(Place p) {\n"""
new_end = """      ]),\n    )));\n  }\n\n  Widget _heightCompatibility(Place p) {\n"""
if old_end not in s:
    raise SystemExit('place sheet closing pattern not found')
s = s.replace(old_end, new_end, 1)

p.write_text(s)
