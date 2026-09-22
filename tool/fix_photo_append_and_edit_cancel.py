from pathlib import Path

# 1) Place registration: newly picked photos must be appended, not replace prior picks.
p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
old = "OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new = "OutlinedButton.icon(onPressed: () async { final remain = 6 - photos.length; if (remain <= 0) { _msg('장소사진은 최대 6장입니다.'); return; } final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: remain); setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:
    s = s.replace(old, new, 1)
elif "final remain = 6 - photos.length" not in s:
    raise SystemExit('place photo picker anchor not found')
p.write_text(s, encoding='utf-8')

# 2) Vehicle listing: append newly selected photos and add an explicit cancel button while editing.
p = Path('lib/screens/vehicle_market_screen.dart')
s = p.read_text(encoding='utf-8')
old = "OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
new = "OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
if old in s:
    s = s.replace(old, new, 1)
elif "final remain=20-oldCount-photos.length" not in s:
    raise SystemExit('vehicle photo picker anchor not found')

old_buttons = "const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
new_buttons = "const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))"
if old_buttons in s:
    s = s.replace(old_buttons, new_buttons, 1)
elif "child:const Text('수정 취소')" not in s:
    raise SystemExit('vehicle edit save button anchor not found')
p.write_text(s, encoding='utf-8')
print('photo append behavior and vehicle edit cancel patched')
