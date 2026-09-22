from pathlib import Path

# Apply conservatively and idempotently. Formatting in these screens changes
# often, so this patch must never fail a build just because a feature is
# already present or an exact whitespace anchor changed.

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
old = "OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new = "OutlinedButton.icon(onPressed: () async { final remain = 6 - photos.length; if (remain <= 0) { _msg('장소사진은 최대 6장입니다.'); return; } final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: remain); setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:
    s = s.replace(old, new, 1)
    print('patched place photo append')
elif 'final remain = 6 - photos.length' in s:
    print('place photo append already patched')
else:
    print('place photo picker changed; retained current implementation')
p.write_text(s, encoding='utf-8')

p = Path('lib/screens/vehicle_market_screen.dart')
s = p.read_text(encoding='utf-8')
# Current source contains spaces after onPressed; support both known forms.
old_variants = [
    "OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",
    "OutlinedButton.icon(onPressed: ()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))",
]
new = "OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
changed = False
for old in old_variants:
    if old in s:
        s = s.replace(old, new, 1)
        changed = True
        print('patched vehicle photo append')
        break
if not changed:
    if 'final remain=20-oldCount-photos.length' in s:
        print('vehicle photo append already patched')
    else:
        print('vehicle photo picker changed; retained current implementation')

old_buttons = "const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
new_buttons = "const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
if old_buttons in s:
    s = s.replace(old_buttons, new_buttons, 1)
    print('added vehicle edit cancel')
elif "child:const Text('수정 취소')" in s:
    print('vehicle edit cancel already present')
else:
    print('vehicle edit buttons changed; retained current implementation')
p.write_text(s, encoding='utf-8')
print('photo/edit compatibility patch complete')
