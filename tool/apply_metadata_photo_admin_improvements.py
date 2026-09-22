from pathlib import Path

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')
old="OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new="OutlinedButton.icon(onPressed: () async { final remain=6-photos.length; if(remain<=0){_msg('장소사진은 최대 6장입니다.');return;} final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain); if(picked.isNotEmpty)setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:s=s.replace(old,new,1)
anchor="        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"
thumbs="""        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-4,top:-4,child:Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>setS(()=>photos.removeAt(i)),child:Container(width:30,height:30,alignment:Alignment.center,decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:20)))))])))),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"""
if anchor in s and 'photos.removeAt(i)' not in s:s=s.replace(anchor,thumbs,1)

detail="        if (p.address.isNotEmpty) Text(p.address),"
if detail in s and "Text('등록자:" not in s:s=s.replace(detail,detail+"\n        Text('등록자: ${p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname}'),\n        if(p.createdAt!=null) Text('최종 등록일자: ${p.createdAt!.toLocal().toString().substring(0,16)}'),",1)
needle="        if (!p.isApproved && _isMine(p)) ...["
admin="""        if(widget.user.isAdministrator) ...[const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('장소 삭제'),content:Text('${p.name} 장소를 삭제할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('삭제'))]));if(ok==true){await widget.data.deletePlace(p.id);if(ctx.mounted)Navigator.pop(ctx);await _load();_msg('장소를 삭제했습니다.');}},icon:const Icon(Icons.delete_outline),label:const Text('관리자 장소 삭제')))],
"""
if needle in s and '관리자 장소 삭제' not in s:s=s.replace(needle,admin+needle,1)

# The build pipeline can inject photo-thumbnail callbacks into other methods too.
# setS is only valid in the add-place StatefulBuilder; remove any injected thumbnail
# block outside that method instead of renaming it to setState (where `photos` may not exist).
start=s.find('  Future<void> _openAddPlace(')
end=s.find('  Widget _placePhoto(', start)
if start < 0 or end < 0: raise SystemExit('add-place function boundaries not found')
add=s[start:end]
# Exact callback must exist only in add-place.
callback='onTap:()=>setS(()=>photos.removeAt(i))'
if callback not in add: raise SystemExit('VALIDATION FAILED: add-place X delete callback missing')
# Strip any duplicate thumbnail expression accidentally injected outside add-place.
thumb_start='if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap('
def strip_bad(region):
    while callback in region:
        pos=region.find(callback)
        a=region.rfind(thumb_start,0,pos)
        if a < 0: raise SystemExit('VALIDATION FAILED: out-of-scope setS found without removable thumbnail block')
        # Find the following minimum-photo text anchor and preserve it.
        marker="const Text('장소사진은 최소 1장 필요합니다.'"
        b=region.find(marker,pos)
        if b < 0: raise SystemExit('VALIDATION FAILED: malformed duplicate photo block')
        region=region[:a]+region[b:]
    return region
before=strip_bad(s[:start])
after=strip_bad(s[end:])
s=before+add+after
# Final hard guard: exactly one photo-delete setS callback in the whole generated file.
if s.count(callback)!=1: raise SystemExit(f'VALIDATION FAILED: expected exactly one scoped photo callback, got {s.count(callback)}')
if 'photos.clear()' in add: raise SystemExit('VALIDATION FAILED: add-place still clears prior photos')
p.write_text(s,encoding='utf-8')

p=Path('lib/screens/vehicle_market_screen.dart');s=p.read_text(encoding='utf-8')
old="OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20'))"
new="OutlinedButton.icon(onPressed:()async{final oldCount=List<String>.from(x?['image_urls']??const []).length;final remain=20-oldCount-photos.length;if(remain<=0){msg('사진은 최대 20장입니다.');return;}final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain);if(p.isNotEmpty)ss((){photos.addAll(p.take(remain));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20')),if(photos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-4,top:-4,child:Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>ss(()=>photos.removeAt(i)),child:Container(width:30,height:30,alignment:Alignment.center,decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:20))))])))"
if old in s:s=s.replace(old,new,1)
s=s.replace("const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))","const SizedBox(height:12),if(isEdit)OutlinedButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('수정 취소')),if(isEdit)const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))")
p.write_text(s,encoding='utf-8')
print('validated exactly one scoped add-place photo callback')
