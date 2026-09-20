from pathlib import Path
p=Path('lib/screens/home_screen.dart');s=p.read_text(encoding='utf-8')
if "import 'feedback_screen.dart';" not in s:
    s=s.replace("import 'vehicle_market_screen.dart';", "import 'vehicle_market_screen.dart';\nimport 'feedback_screen.dart';\nimport 'admin_management_screen.dart';")
anchor="          OutlinedButton(onPressed: _vehicleDialog, child: const Text('차량정보 변경'))," 
if anchor in s and "앱 이용 / 의견 제출" not in s:
    s=s.replace(anchor,anchor+"\n          const SizedBox(height: 8),\n          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())), icon: const Icon(Icons.feedback_outlined), label: const Text('앱 이용 / 의견 제출')),\n          if (widget.user.isAdministrator) ...[\n            const SizedBox(height: 8),\n            FilledButton.tonalIcon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminManagementScreen())), icon: const Icon(Icons.admin_panel_settings), label: const Text('관리자 통합관리')),\n          ],")
s=s.replace("const Text('이용안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))","const Text('이용안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))")
s=s.replace("const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))","const Text('캠핑카 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))")
needle="        _serviceAvailability(p),\n        const Text('이용안내',"
if needle in s:
    s=s.replace(needle,"        const Text('이용안내',",1)
    for a in ["        if (p.note.isNotEmpty) Text('이용방법/주의사항: ${p.note}'),","        if (p.note.isNotEmpty) Text('이용방법 / 주의사항: ${p.note}'),"]:
        if a in s:
            s=s.replace(a,a+"\n        const SizedBox(height: 16),\n        _serviceAvailability(p),",1);break
p.write_text(s,encoding='utf-8')

# Keep the checked-in market source, but repair the compact detail method that
# previously produced a parser error at line 24.
mp=Path('lib/screens/vehicle_market_screen.dart')
lines=mp.read_text(encoding='utf-8').splitlines()
for i,line in enumerate(lines):
    if line.lstrip().startswith('Future<void> detail('):
        lines[i]=""" Future<void> detail(Map<String,dynamic> x) async {
  final photos=List<String>.from(x['image_urls']??const []);
  final mine=x['owner_id']==uid;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(ctx)=>SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[
     if(photos.isNotEmpty) SizedBox(height:220,child:PageView(children:photos.map((u)=>ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(u,fit:BoxFit.cover))).toList())),
     const SizedBox(height:10),
     Row(children:[Expanded(child:Text('${x['title']}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold))),Chip(label:Text(x['status']=='sold'?'판매완료':'판매중'))]),
     Text('${x['manufacturer']} ${x['model']} · ${x['model_year']??'-'}년'),
     Text('주행거리 ${x['mileage_km']??'-'}km · ${x['region']}'),
     Text(money(x['price_krw']),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const Divider(),
     Text('배터리 ${x['battery_ah']??'없음'}Ah · 태양광 ${x['solar_w']??'없음'}W'),
     Text('인버터 ${x['inverter_w']??'없음'}W · 주행충전 ${x['alternator_charger_a']??'없음'}A'),
     Text('한전충전 ${x['shore_power']==true?'있음':'없음'} · 청수 ${x['fresh_water_l']??'없음'}L · 오수 ${x['grey_water_l']??'없음'}L'),
     Text('화장실 ${x['toilet_type']=='cassette'?'카트리지':x['toilet_type']=='black'?'블랙':'없음'} ${x['toilet_capacity_l']??''}${x['toilet_capacity_l']!=null?'L':''}'),
     if('${x['description']??''}'.isNotEmpty) Padding(padding:const EdgeInsets.only(top:10),child:Text('${x['description']}')),
     const SizedBox(height:10),Text('연락처: ${x['phone']}'),const SizedBox(height:12),
     if(mine) Wrap(spacing:8,children:[
      OutlinedButton(onPressed:(){Navigator.pop(ctx);edit(x);},child:const Text('수정')),
      OutlinedButton(onPressed:(){Navigator.pop(ctx);ownerAction(x,x['status']=='sold'?'active':'sold');},child:Text(x['status']=='sold'?'판매중으로 변경':'판매완료')),
      TextButton(onPressed:(){Navigator.pop(ctx);ownerAction(x,'delete');},child:const Text('삭제')),
     ]) else OutlinedButton.icon(onPressed:()=>report(x),icon:const Icon(Icons.report_outlined),label:const Text('매물 신고')),
    ],
   ))),
  );
 }"""
        break
mp.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('market support applied; vehicle market detail parser repair applied')
