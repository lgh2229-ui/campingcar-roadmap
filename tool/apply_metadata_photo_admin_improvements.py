from pathlib import Path

# This CI patch is intentionally narrow and idempotent. Earlier feature
# patches already apply the requested metadata/admin features; here we fix
# the photo-selection regression and the analyzer failure safely.
p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')

# Never clear previously selected place photos when the user adds more.
s=s.replace('photos.clear(); photos.addAll(picked);','photos.addAll(picked.take(6-photos.length));')
s=s.replace('photos.clear();photos.addAll(picked);','photos.addAll(picked.take(6-photos.length));')

# The place registration dialog uses StatefulBuilder callback `setDialogState`.
# A previous generated patch incorrectly emitted `setS`, which is undefined.
s=s.replace('onTap:()=>setS(()=>photos.removeAt(i))','onTap:()=>setDialogState(()=>photos.removeAt(i))')

# Add removable thumbnails if an earlier pass did not already add them.
anchor="        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"
thumbs="""        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>Stack(clipBehavior:Clip.none,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),width:88,height:70,fit:BoxFit.cover)),Positioned(right:-6,top:-6,child:InkWell(onTap:()=>setDialogState(()=>photos.removeAt(i)),child:Container(decoration:const BoxDecoration(color:Colors.black87,shape:BoxShape.circle),padding:const EdgeInsets.all(3),child:const Icon(Icons.close,color:Colors.white,size:16))))])))),
        const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),"""
if anchor in s and 'photos.removeAt(i)' not in s:
    s=s.replace(anchor,thumbs,1)

p.write_text(s,encoding='utf-8')
print('fixed place photo append/delete callback scope')
