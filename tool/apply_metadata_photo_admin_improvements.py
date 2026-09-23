from pathlib import Path

# IMPORTANT: place-photo selection/preview/delete is owned exclusively by
# tool/fix_photo_append_and_edit_cancel.py, which runs immediately before this script.
# Do not rewrite that UI here. This script only applies metadata/admin additions.
p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')

detail="        if (p.address.isNotEmpty) Text(p.address),"
if detail in s and "Text('등록자:" not in s:
    s=s.replace(detail,detail+"\n        Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n        if(p.createdAt!=null) Text('최종 등록일자: ${p.createdAt!.toLocal().toString().substring(0,16)}'),",1)
needle="        if (!p.isApproved && _isMine(p)) ...["
admin="""        if(widget.user.isAdministrator) ...[const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('장소 삭제'),content:Text('${p.name} 장소를 삭제할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('삭제'))]));if(ok==true){await widget.data.deletePlace(p.id);if(ctx.mounted)Navigator.pop(ctx);await _load();_msg('장소를 삭제했습니다.');}},icon:const Icon(Icons.delete_outline),label:const Text('관리자 장소 삭제')))],
"""
if needle in s and '관리자 장소 삭제' not in s:
    s=s.replace(needle,admin+needle,1)

# Verify the already-applied photo UI survives this later CI step byte-for-byte in behavior.
start=s.find('  Future<void> _openAddPlace(')
end=s.find('  Widget _placePhoto(', start)
if start < 0 or end < 0: raise SystemExit('add-place function boundaries not found')
add=s[start:end]
required=[
    'pickMultiImage(imageQuality: 82)',
    'photos.addAll(additions)',
    'ValueKey(photo.path)',
    'HitTestBehavior.opaque',
    'photos.removeWhere((x) => x.path == photo.path)',
]
missing=[x for x in required if x not in add]
if 'photos.clear()' in add or missing:
    raise SystemExit('VALIDATION FAILED: place photo UI was overwritten: '+','.join(missing))
p.write_text(s,encoding='utf-8')

# Vehicle-market compatibility only. Do not touch place-photo UI above.
p=Path('lib/screens/vehicle_market_screen.dart')
s=p.read_text(encoding='utf-8')
old="OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
new="OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82);if(p.isNotEmpty)ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
if old in s:s=s.replace(old,new,1)
s=s.replace("const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))","const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))")
p.write_text(s,encoding='utf-8')
print('preserved verified place-photo UI; metadata/admin patch complete')
