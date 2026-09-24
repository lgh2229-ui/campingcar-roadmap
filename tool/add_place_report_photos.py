from pathlib import Path

p=Path('lib/screens/home_screen.dart')
s=p.read_text(encoding='utf-8')
if "package:supabase_flutter/supabase_flutter.dart" not in s:
    s=s.replace("import 'package:latlong2/latlong.dart';", "import 'package:latlong2/latlong.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';",1)
anchor='  Widget _heightCompatibility(Place p)'
if anchor not in s: raise SystemExit('place report: height anchor missing')
if 'Future<void> _reportPlace(Place p)' not in s:
    methods=r'''  Future<void> _showLocalReportPhotos(List<XFile> photos,int initial) async {
    if(photos.isEmpty)return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(viewerContext){
      return Scaffold(
        backgroundColor:Colors.black,
        appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:const Text('첨부사진')),
        body:PageView.builder(
          controller:PageController(initialPage:initial),
          itemCount:photos.length,
          itemBuilder:(pageContext,i)=>InteractiveViewer(
            minScale:1,
            maxScale:5,
            child:Center(child:Image.file(File(photos[i].path),fit:BoxFit.contain)),
          ),
        ),
      );
    }));
  }

  Future<void> _reportPlace(Place p) async {
    if (widget.user.isAdministrator) return;
    String type='정보 오류';
    final body=TextEditingController();
    final photos=<XFile>[];
    bool sending=false;
    final ok=await showDialog<bool>(context:context,barrierDismissible:false,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setD)=>AlertDialog(
      title:const Text('장소 신고'),
      content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold)),
        DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'신고 사유'),items:['정보 오류','이용 불가','폐쇄/없어진 장소','부적절한 내용','기타'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:sending?null:(v)=>setD(()=>type=v??type)),
        const SizedBox(height:8),TextField(controller:body,maxLines:4,enabled:!sending,decoration:const InputDecoration(labelText:'상세 내용',hintText:'확인이 필요한 내용을 입력해주세요.',border:OutlineInputBorder())),const SizedBox(height:10),
        OutlinedButton.icon(onPressed:sending?null:()async{final remain=5-photos.length;if(remain<=0)return;final picked=await ImagePicker().pickMultiImage(imageQuality:82);if(!dialogContext.mounted||picked.isEmpty)return;final existing=photos.map((e)=>e.path).toSet();setD(()=>photos.addAll(picked.where((e)=>!existing.contains(e.path)).take(remain)));},icon:const Icon(Icons.photo_library_outlined),label:Text('사진 첨부 (${photos.length}/5)')),
        if(photos.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:8,runSpacing:8,children:List.generate(photos.length,(i)=>SizedBox(width:88,height:76,child:Stack(clipBehavior:Clip.none,children:[Positioned.fill(child:GestureDetector(onTap:()=>_showLocalReportPhotos(List<XFile>.from(photos),i),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(photos[i].path),fit:BoxFit.cover)))),Positioned(right:-5,top:-5,child:IconButton.filled(constraints:const BoxConstraints.tightFor(width:32,height:32),padding:EdgeInsets.zero,onPressed:sending?null:()=>setD(()=>photos.removeAt(i)),icon:const Icon(Icons.close,size:18)))])))))
      ]))),
      actions:[TextButton(onPressed:sending?null:()=>Navigator.pop(dialogContext,false),child:const Text('취소')),FilledButton(onPressed:sending?null:()async{if(body.text.trim().isEmpty)return;setD(()=>sending=true);try{final db=Supabase.instance.client;final uid=db.auth.currentUser?.id;if(uid==null)throw Exception('로그인이 필요합니다.');final urls=<String>[];for(final x in photos){final ext=x.path.split('.').last.toLowerCase();final safe=RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)?ext:'jpg';final path='$uid/${p.id}/${const Uuid().v4()}.$safe';await db.storage.from('report-photos').upload(path,File(x.path),fileOptions:const FileOptions(cacheControl:'3600',upsert:false));urls.add(db.storage.from('report-photos').getPublicUrl(path));}await db.from('place_reports').insert({'place_id':p.id,'reporter_id':uid,'report_type':type,'body':body.text.trim(),'photo_urls':urls});if(dialogContext.mounted)Navigator.pop(dialogContext,true);}catch(e){if(dialogContext.mounted){setD(()=>sending=false);ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text('신고 접수에 실패했습니다: $e')));}}},child:Text(sending?'접수 중...':'신고 접수'))]
    )));
    body.dispose();if(ok==true&&mounted)_msg('신고가 접수되었습니다.');
  }

'''
    s=s.replace(anchor,methods+anchor,1)
needle="            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n          ]),"
if needle in s and "label: const Text('신고')" not in s:
    s=s.replace(needle,"            Expanded(child: FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _openReview(p); }, child: const Text('검증리뷰'))),\n          ]),\n          if (!widget.user.isAdministrator) ...[\n            const SizedBox(height: 8),\n            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); Future.delayed(const Duration(milliseconds: 120), () => _reportPlace(p)); }, icon: const Icon(Icons.report_outlined), label: const Text('신고'))),\n          ],",1)
if 'Future<void> _reportPlace(Place p)' not in s or "label: const Text('신고')" not in s: raise SystemExit('place report UI patch missing')
p.write_text(s,encoding='utf-8')

p=Path('lib/screens/admin_management_screen.dart')
a=p.read_text(encoding='utf-8')
a=a.replace("List<Map<String,dynamic>> market=[],members=[],feedback=[],reports=[];", "List<Map<String,dynamic>> market=[],members=[],feedback=[],reports=[],placeReports=[];")
a=a.replace("db.from('vehicle_market_reports').select().order('created_at',ascending:false)])", "db.from('vehicle_market_reports').select().order('created_at',ascending:false),db.from('place_reports').select().order('created_at',ascending:false)])",1)
a=a.replace("reports=List<Map<String,dynamic>>.from(a[3]);", "reports=List<Map<String,dynamic>>.from(a[3]);placeReports=List<Map<String,dynamic>>.from(a[4]);",1)
if 'Future<void> _openReportPhoto(' not in a:
    marker=' @override Widget build(BuildContext context)'
    if marker not in a: raise SystemExit('admin report build anchor missing')
    methods=r''' Future<void> _openReportPhoto(List<String> urls,int initial) async {
  if(urls.isEmpty)return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder:(viewerContext){
   return Scaffold(
    backgroundColor:Colors.black,
    appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:const Text('첨부사진')),
    body:PageView.builder(
     controller:PageController(initialPage:initial),
     itemCount:urls.length,
     itemBuilder:(pageContext,i){
      return InteractiveViewer(minScale:1,maxScale:5,child:Center(child:Image.network(urls[i],fit:BoxFit.contain,errorBuilder:(context,error,stackTrace)=>const Icon(Icons.broken_image,color:Colors.white,size:64))));
     },
    ),
   );
  }));
 }
 Future<void> _showPlaceReport(Map<String,dynamic>x) async {
  final raw=x['photo_urls'];
  final urls=raw is List?raw.map((e)=>'$e').where((e)=>e.isNotEmpty).toList():<String>[];
  await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(sheetContext){
   return SafeArea(child:SizedBox(height:MediaQuery.of(sheetContext).size.height*.8,child:ListView(padding:const EdgeInsets.all(16),children:[
    Text('장소 신고',style:Theme.of(sheetContext).textTheme.titleLarge),
    const SizedBox(height:12),Text('신고자: ${_name(x['reporter_id'])}'),Text('요청: ${_dt(x['created_at'])}'),Text('사유: ${x['report_type']??''}'),const SizedBox(height:8),Text('${x['body']??''}'),
    if(urls.isNotEmpty)...[const SizedBox(height:14),const Text('첨부사진',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:List.generate(urls.length,(i){return InkWell(onTap:()=>_openReportPhoto(urls,i),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(urls[i],width:105,height:90,fit:BoxFit.cover,errorBuilder:(context,error,stackTrace)=>const SizedBox(width:105,height:90,child:Icon(Icons.broken_image)))));}))]
   ])));
  });
 }
'''
    a=a.replace(marker,methods+marker,1)
old="ListView.builder(itemCount:reports.length,itemBuilder:(_,i){final x=reports[i];return ListTile(leading:const Icon(Icons.report),title:Text('매물 ${x['listing_id']}'),subtitle:Text('${x['reason']}\\n신고자: ${_name(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}'),isThreeLine:true,trailing:Text('${x['status']}'));})"
new="ListView(children:[if(placeReports.isNotEmpty)const ListTile(title:Text('장소 신고',style:TextStyle(fontWeight:FontWeight.bold))),...placeReports.map((x)=>ListTile(leading:const Icon(Icons.place_outlined),title:Text('장소 ${x['place_id']}'),subtitle:Text('${x['report_type']??''} · 신고자: ${_name(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}'),onTap:()=>_showPlaceReport(x))),if(reports.isNotEmpty)const ListTile(title:Text('중고매물 신고',style:TextStyle(fontWeight:FontWeight.bold))),...reports.map((x)=>ListTile(leading:const Icon(Icons.report),title:Text('매물 ${x['listing_id']}'),subtitle:Text('${x['reason']}\\n신고자: ${_name(x['reporter_id'])} · 요청: ${_dt(x['created_at'])}'),isThreeLine:true,trailing:Text('${x['status']}')))])"
if old in a:a=a.replace(old,new,1)
if "db.from('place_reports')" not in a or '_showPlaceReport' not in a or '_openReportPhoto' not in a: raise SystemExit('admin place report patch missing')
p.write_text(a,encoding='utf-8')
print('OK: place report photos and viewer patch applied')
