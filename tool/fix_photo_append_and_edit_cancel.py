from pathlib import Path

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')
start=s.find('  Future<void> _openAddPlace(')
end=s.find('  Widget _placePhoto(',start)
if start<0 or end<0: raise SystemExit('FAILED: add-place boundaries not found')
block=s[start:end]
if 'builder: (pageContext, setPageState)' not in block:
    raise SystemExit('FAILED: registration StatefulBuilder/setPageState not found')
label=block.find("label: Text('장소사진")
btn=block.rfind('OutlinedButton.icon(',0,label) if label>=0 else -1
marker="const Text('장소사진은 최소 1장 필요합니다.'"
mark=block.find(marker,btn)
if btn<0 or mark<0: raise SystemExit('FAILED: photo UI anchors not found')
replacement="""OutlinedButton.icon(
          onPressed: saving ? null : () async {
            final remain = 6 - photos.length;
            if (remain <= 0) { ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text('장소사진은 최대 6장입니다.'))); return; }
            try {
              final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
              if (!pageContext.mounted || picked.isEmpty) return;
              final additions = picked.take(remain).toList();
              setPageState(() { photos.addAll(additions); });
            } catch (e) {
              if (pageContext.mounted) ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text('사진 선택에 실패했습니다. 다시 시도해주세요.')));
            }
          },
          icon: const Icon(Icons.photo_library_outlined),
          label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'),
        ),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(photos.length, (i) {
                final photo = photos[i];
                return SizedBox(
                  key: ValueKey(photo.path),
                  width: 100,
                  height: 86,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photo.path), fit: BoxFit.cover))),
                    Positioned(right: -4, top: -4, child: IconButton.filled(
                      tooltip: '사진 삭제',
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      onPressed: saving ? null : () { setPageState(() { photos.removeAt(i); }); },
                      icon: const Icon(Icons.close, size: 20),
                    )),
                  ]),
                );
              }),
            ),
          ),
        """
block=block[:btn]+replacement+block[mark:]
s=s[:start]+block+s[end:]
final_block=s[start:s.find('  Widget _placePhoto(',start)]
required=['builder: (pageContext, setPageState)','pickMultiImage(imageQuality: 82)','setPageState(() { photos.addAll(additions); })','Image.file(File(photo.path)','setPageState(() { photos.removeAt(i); })']
missing=[x for x in required if x not in final_block]
if 'photos.clear()' in final_block or 'setS(() { photos.' in final_block or missing:
    raise SystemExit('FAILED photo page-state validation: '+','.join(missing))

# Place save button: persistence was succeeding but the modal did not visually rebuild.
# Close the detail sheet after success, then show an explicit confirmation on the main screen.
old="try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { _msg('저장 처리에 실패했습니다: $e'); }"
new="try { await widget.data.saveSavedIds(saved); if (mounted) setState(() {}); if (ctx.mounted) Navigator.pop(ctx); _msg(wasSaved ? '저장에서 해제했습니다.' : '저장한 장소에 추가했습니다.'); } catch (e) { if (wasSaved) { saved.add(p.id); } else { saved.remove(p.id); } if (mounted) setState(() {}); _msg('저장 처리에 실패했습니다: $e'); }"
if old in s:
    s=s.replace(old,new,1)
if new not in s:
    raise SystemExit('FAILED: place save feedback patch missing')
p.write_text(s,encoding='utf-8')

p=Path('lib/screens/vehicle_market_screen.dart')
s=p.read_text(encoding='utf-8')
old="const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
if old in s:
    s=s.replace(old,"const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))",1)
# Always show sale state directly in each list row, including active listings.
old_title="title:Row(children:[Expanded(child:Text('${x['title']}')),if(x['status']=='sold')const Chip(label:Text('판매완료'))]),"
new_title="title:Row(children:[Expanded(child:Text('${x['title']}')),const SizedBox(width:6),Chip(label:Text(x['status']=='sold'?'판매완료':'판매중'))]),"
if old_title in s:
    s=s.replace(old_title,new_title,1)
if new_title not in s:
    raise SystemExit('FAILED: vehicle market list status badge patch missing')
p.write_text(s,encoding='utf-8')
print('OK: photo behavior preserved; place save feedback visible; market list always shows sale status')
