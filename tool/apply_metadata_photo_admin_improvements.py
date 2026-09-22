from pathlib import Path

# CI compatibility patch for place registration photos.
p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')

# The current place-registration StatefulBuilder callback is `setS`.
# Preserve already-selected photos and only append up to the 6-photo limit.
old="OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6); setS(() { photos.clear(); photos.addAll(picked); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
new="OutlinedButton.icon(onPressed: () async { final remain=6-photos.length; if(remain<=0){_msg('장소사진은 최대 6장입니다.');return;} final picked=await ImagePicker().pickMultiImage(imageQuality:82,limit:remain); setS(() { photos.addAll(picked.take(remain)); }); }, icon: const Icon(Icons.photo_library_outlined), label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'))"
if old in s:
    s=s.replace(old,new,1)
else:
    s=s.replace('photos.clear(); photos.addAll(picked);','photos.addAll(picked.take(6-photos.length));')
    s=s.replace('photos.clear();photos.addAll(picked);','photos.addAll(picked.take(6-photos.length));')

# Repair any bad callback emitted by an earlier build patch.
s=s.replace('onTap:()=>setDialogState(()=>photos.removeAt(i))','onTap:()=>setS(()=>photos.removeAt(i))')

# Show every newly selected photo before registration, with an X delete button.
anchor="        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"
thumbs="""        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>setS(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"""
if anchor in s and 'photos.removeAt(i)' not in s:
    s=s.replace(anchor,thumbs,1)

p.write_text(s,encoding='utf-8')
print('fixed place photo append and X-delete using setS')
