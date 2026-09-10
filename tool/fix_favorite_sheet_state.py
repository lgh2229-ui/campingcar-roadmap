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

# Verification review list must also rebuild inside the open detail sheet.
s = s.replace(
    "    final reviews = p.isApproved ? await widget.data.reviews(p.id) : <PlaceReview>[];\n",
    "    var reviews = p.isApproved ? await widget.data.reviews(p.id) : <PlaceReview>[];\n",
    1,
)

old_review_button = """            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n"""
new_review_button = """            Expanded(child: FilledButton.tonal(onPressed: () async {\n              await _openReview(p);\n              final fresh = await widget.data.reviews(p.id);\n              if (ctx.mounted) setSheetState(() { reviews = fresh; });\n            }, child: const Text('검증리뷰'))),\n"""
if old_review_button not in s:
    raise SystemExit('verification review button pattern not found')
s = s.replace(old_review_button, new_review_button, 1)

old_tile_call = """          ...reviews.map((r) => _reviewTile(p, r)),\n"""
new_tile_call = """          ...reviews.map((r) => _reviewTile(p, r, onChanged: () async {\n            final fresh = await widget.data.reviews(p.id);\n            if (ctx.mounted) setSheetState(() { reviews = fresh; });\n          })),\n"""
if old_tile_call not in s:
    raise SystemExit('review tile call pattern not found')
s = s.replace(old_tile_call, new_tile_call, 1)

old_signature = "  Widget _reviewTile(Place p, PlaceReview r) {\n"
new_signature = "  Widget _reviewTile(Place p, PlaceReview r, {Future<void> Function()? onChanged}) {\n"
if old_signature not in s:
    raise SystemExit('review tile signature pattern not found')
s = s.replace(old_signature, new_signature, 1)

old_menu = """            if (mine) PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _editReview(p, r); if (v == 'delete') await _deleteReview(p, r); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))]),\n"""
new_menu = """            if (mine) PopupMenuButton<String>(onSelected: (v) async {\n              if (v == 'edit') await _editReview(p, r);\n              if (v == 'delete') await _deleteReview(p, r);\n              if (onChanged != null) await onChanged();\n            }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))]),\n"""
if old_menu not in s:
    raise SystemExit('review popup menu pattern not found')
s = s.replace(old_menu, new_menu, 1)

old_after_add = """    try { await widget.data.addReview(placeId: p.id, status: status, body: body.text); _msg('검증리뷰가 등록되었습니다.'); await _load(); if (mounted) _showPlace(p); } catch (e) { _msg('리뷰 등록에 실패했습니다: $e'); }\n"""
new_after_add = """    try { await widget.data.addReview(placeId: p.id, status: status, body: body.text); _msg('검증리뷰가 등록되었습니다.'); await _load(); } catch (e) { _msg('리뷰 등록에 실패했습니다: $e'); }\n"""
if old_after_add not in s:
    raise SystemExit('review add completion pattern not found')
s = s.replace(old_after_add, new_after_add, 1)

old_end = """      ]),\n    ));\n  }\n\n  Widget _heightCompatibility(Place p) {\n"""
new_end = """      ]),\n    )));\n  }\n\n  Widget _heightCompatibility(Place p) {\n"""
if old_end not in s:
    raise SystemExit('place sheet closing pattern not found')
s = s.replace(old_end, new_end, 1)

p.write_text(s)
