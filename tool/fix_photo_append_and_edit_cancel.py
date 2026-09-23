from pathlib import Path

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')
start=s.find('  Future<void> _openAddPlace(')
end=s.find('  Widget _placePhoto(',start)
if start<0 or end<0: raise SystemExit('FAILED: add-place boundaries not found')
block=s[start:end]
label=block.find("label: Text('장소사진")
btn=block.rfind('OutlinedButton.icon(',0,label) if label>=0 else -1
marker="const Text('장소사진은 최소 1장 필요합니다.'"
mark=block.find(marker,btn)
if btn<0 or mark<0: raise SystemExit('FAILED: photo UI anchors not found')
replacement="""OutlinedButton.icon(
          onPressed: () async {
            final remain = 6 - photos.length;
            if (remain <= 0) { _msg('장소사진은 최대 6장입니다.'); return; }
            try {
              final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
              if (picked.isEmpty) return;
              final additions = picked.take(remain).toList();
              setS(() { photos.addAll(additions); });
            } catch (e) {
              _msg('사진 선택에 실패했습니다. 다시 시도해주세요.');
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
                    Positioned(right: -4, top: -4, child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { setS(() { photos.removeWhere((x) => x.path == photo.path); }); },
                      child: Container(width: 36, height: 36, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 22)),
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
required=['pickMultiImage(imageQuality: 82)','photos.addAll(additions)',"ValueKey(photo.path)",'HitTestBehavior.opaque','photos.removeWhere((x) => x.path == photo.path)']
missing=[x for x in required if x not in final_block]
if 'photos.clear()' in final_block or missing: raise SystemExit('FAILED photo behavior validation: '+','.join(missing))
p.write_text(s,encoding='utf-8')

p=Path('lib/screens/vehicle_market_screen.dart')
s=p.read_text(encoding='utf-8')
for old in [
"OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",
"OutlinedButton.icon(onPressed: ()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"]:
 if old in s:
  s=s.replace(old,"OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82);if(p.isNotEmpty)ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",1);break
old="const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
if old in s:s=s.replace(old,"const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))",1)
p.write_text(s,encoding='utf-8')
print('validated place photo picker append + preview + X delete behavior')
