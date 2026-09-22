from pathlib import Path
import re

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')
start=s.find('  Future<void> _openAddPlace(')
end=s.find('  Widget _placePhoto(',start)
if start<0 or end<0: raise SystemExit('FAILED: add-place boundaries not found')
block=s[start:end]

# Earlier CI steps may reformat this widget. Locate by semantic anchors, not exact whitespace.
btn=block.find('OutlinedButton.icon(', block.find("'장소사진"))
if btn<0:
    # button usually starts before the label, so search backwards from label
    label=block.find("label: Text('장소사진")
    btn=block.rfind('OutlinedButton.icon(',0,label) if label>=0 else -1
if btn<0: raise SystemExit('FAILED: add-place photo button not found')
marker="const Text('장소사진은 최소 1장 필요합니다.'"
mark=block.find(marker,btn)
if mark<0: raise SystemExit('FAILED: minimum-photo marker not found')
# Replace from button through immediately before marker; this also removes stale/duplicate preview blocks.
replacement="""OutlinedButton.icon(
          onPressed: () async {
            final remain = 6 - photos.length;
            if (remain <= 0) { _msg('장소사진은 최대 6장입니다.'); return; }
            final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: remain);
            if (picked.isNotEmpty) setS(() { photos.addAll(picked.take(remain)); });
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
              children: List.generate(photos.length, (i) => SizedBox(
                width: 96,
                height: 82,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photos[i].path), fit: BoxFit.cover))),
                  Positioned(right: -4, top: -4, child: Material(color: Colors.transparent, child: InkWell(
                    key: ValueKey('place-photo-delete-$i-${photos[i].path}'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () { setS(() { if (i >= 0 && i < photos.length) photos.removeAt(i); }); },
                    child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                  ))),
                ]),
              )),
            ),
          ),
        """
block=block[:btn]+replacement+block[mark:]
s=s[:start]+block+s[end:]

# Validate the exact source handed to Flutter after all earlier patch steps.
block=s[start:start+len(block)]
checks={
 'no photo clear':'photos.clear()' not in block,
 'append photos':'photos.addAll(picked.take(remain))' in block,
 'preview':'Image.file(File(photos[i].path)' in block,
 'delete button':"ValueKey('place-photo-delete-" in block,
 'delete action':'photos.removeAt(i)' in block,
 'dialog refresh':'setS(() {' in block,
}
bad=[k for k,v in checks.items() if not v]
if bad: raise SystemExit('FAILED add-place photo validation: '+', '.join(bad))
p.write_text(s,encoding='utf-8')

p=Path('lib/screens/vehicle_market_screen.dart')
s=p.read_text(encoding='utf-8')
for old in [
"OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",
"OutlinedButton.icon(onPressed: ()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"]:
 if old in s:
  s=s.replace(old,"OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);if(p.isNotEmpty)ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",1);break
old="const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
if old in s:s=s.replace(old,"const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))",1)
p.write_text(s,encoding='utf-8')
print('validated semantic add-place photo append/preview/X-delete')
