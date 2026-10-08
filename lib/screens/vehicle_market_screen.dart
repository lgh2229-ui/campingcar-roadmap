import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleMarketScreen extends StatefulWidget {
  const VehicleMarketScreen({super.key});
  @override
  State<VehicleMarketScreen> createState() => _VehicleMarketScreenState();
}

class _VehicleMarketScreenState extends State<VehicleMarketScreen> {
  final db = Supabase.instance.client;
  final search = TextEditingController();
  bool loading = true;
  List<Map<String, dynamic>> rows = [];
  String q = '', status = '전체', toilet = '전체', freshFilter = '전체', greyFilter = '전체', region = '전체', priceFilter = '전체', yearFilter = '전체', batteryFilter = '전체', solarFilter = '전체', inverterFilter = '전체', alternatorFilter = '전체';
  int? minPrice, maxPrice, minYear, maxYear, maxKm, minBattery, maxBattery, minSolar, maxSolar, minInverter, maxInverter, minAlternator, maxAlternator, minFresh, minGrey, minToilet;
  bool? shore;
  String get uid => db.auth.currentUser?.id ?? '';

  @override void initState() { super.initState(); load(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  int? iv(Map<String,dynamic> x,String k) => x[k] == null ? null : int.tryParse('${x[k]}');
  String money(dynamic v) { final n=int.tryParse('$v'); if(n==null)return '가격 협의'; return '${n.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'),(_)=>',')}원'; }
  Widget num(TextEditingController c,String label,String unit) => TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'$label ($unit)',border:const OutlineInputBorder()));

  Future<void> load() async { try { final d=await db.from('vehicle_market_listings').select().order('created_at',ascending:false); if(mounted)setState((){rows=List<Map<String,dynamic>>.from(d);loading=false;}); } catch(e){if(mounted){setState(()=>loading=false);msg('매물을 불러오지 못했습니다: $e');}} }

  List<Map<String,dynamic>> get filtered => rows.where((x){
    if(status!='전체' && '${x['status']}'!=(status=='판매중'?'active':'sold')) return false;
    final z=q.toLowerCase(); if(z.isNotEmpty && !('${x['title']} ${x['manufacturer']} ${x['model']} ${x['region']}'.toLowerCase().contains(z))) return false;
    if(region!='전체' && !('${x['region']}'.contains(region))) return false;
    bool range(String k,int? lo,int? hi){final v=iv(x,k);return (lo==null||(v!=null&&v>=lo))&&(hi==null||(v!=null&&v<=hi));}
    if(priceFilter=='금액설정' && !range('price_krw',minPrice,maxPrice)) return false;
    if(yearFilter=='연식설정' && !range('model_year',minYear,maxYear)) return false;
    if(!range('mileage_km',null,maxKm)) return false;
    bool optionMatch(String mode,String key,int? lo,int? hi){final v=iv(x,key);if(mode=='전체')return true;if(mode=='없음')return v==null;if(mode=='있음')return v!=null&&range(key,lo,hi);return true;}
    if(!optionMatch(batteryFilter,'battery_ah',minBattery,maxBattery)||!optionMatch(solarFilter,'solar_w',minSolar,maxSolar)||!optionMatch(inverterFilter,'inverter_w',minInverter,maxInverter)||!optionMatch(alternatorFilter,'alternator_charger_a',minAlternator,maxAlternator)) return false;
    if(freshFilter=='없음' && x['fresh_water_l']!=null) return false; if(freshFilter=='있음' && (iv(x,'fresh_water_l')==null || (minFresh!=null&&!range('fresh_water_l',minFresh,null)))) return false;
    if(greyFilter=='없음' && x['grey_water_l']!=null) return false; if(greyFilter=='있음' && (iv(x,'grey_water_l')==null || (minGrey!=null&&!range('grey_water_l',minGrey,null)))) return false;
    if(toilet!='전체' && '${x['toilet_type']}'!=toilet) return false; if(minToilet!=null&&!range('toilet_capacity_l',minToilet,null)) return false; if(shore!=null&&x['shore_power']!=shore) return false; return true;
  }).toList();

  Future<List<String>> upload(List<XFile> photos) async { final out=<String>[]; for(var i=0;i<photos.length;i++){final f=photos[i],path='$uid/${DateTime.now().microsecondsSinceEpoch}_$i.jpg';await db.storage.from('vehicle-market').upload(path,File(f.path),fileOptions:const FileOptions(upsert:false));out.add(db.storage.from('vehicle-market').getPublicUrl(path));} return out; }

  Future<void> filters() async {
    TextEditingController c(int? v)=>TextEditingController(text:v?.toString()??'');
    final a=c(minPrice),b=c(maxPrice),y1=c(minYear),y2=c(maxYear),km=c(maxKm);
    final ba1=c(minBattery),ba2=c(maxBattery),so1=c(minSolar),so2=c(maxSolar),inv1=c(minInverter),inv2=c(maxInverter),alt1=c(minAlternator),alt2=c(maxAlternator);
    final fr=c(minFresh),gr=c(minGrey),tc=c(minToilet);
    var st=status,tt=toilet,ff=freshFilter,gf=greyFilter,reg=region,pf=priceFilter,yf=yearFilter,bf=batteryFilter,sf=solarFilter,inf=inverterFilter,af=alternatorFilter; bool? sh=shore;
    const regions=['전체','서울','경기','인천','부산','대구','대전','광주','울산','세종','강원','충북','충남','전북','전남','경북','경남','제주'];
    Widget select(String label,String value,List<String> values,ValueChanged<String> onChanged)=>DropdownButtonFormField<String>(initialValue:value,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:values.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)onChanged(v);});
    Widget rangeFields(TextEditingController lo,TextEditingController hi,String unit)=>Row(children:[Expanded(child:TextField(controller:lo,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'최저',suffixText:unit,border:const OutlineInputBorder()))),const Padding(padding:EdgeInsets.symmetric(horizontal:6),child:Text('~')),Expanded(child:TextField(controller:hi,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'최고',suffixText:unit,border:const OutlineInputBorder())))]);
    Widget option(String label,String mode,TextEditingController lo,TextEditingController hi,String unit,ValueChanged<String> change)=>Column(children:[select(label,mode,const ['전체','없음','있음'],(v)=>ss(()=>change(v))),if(mode=='있음')...[const SizedBox(height:6),rangeFields(lo,hi,unit)],const SizedBox(height:8)]);
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal){ss=setLocal;return SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,0,16,MediaQuery.of(ctx).viewInsets.bottom+12),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('중고차 상세 필터',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),
      select('판매상태',st,const ['전체','판매중','판매완료'],(v)=>ss(()=>st=v)),const SizedBox(height:8),
      select('판매지역',reg,regions,(v)=>ss(()=>reg=v)),const SizedBox(height:8),
      select('금액',pf,const ['전체','금액설정'],(v)=>ss(()=>pf=v)),if(pf=='금액설정')...[const SizedBox(height:6),rangeFields(a,b,'원')],const SizedBox(height:8),
      select('연식',yf,const ['전체','연식설정'],(v)=>ss(()=>yf=v)),if(yf=='연식설정')...[const SizedBox(height:6),rangeFields(y1,y2,'년')],const SizedBox(height:8),
      num(km,'최대 주행거리','km'),const Divider(height:24),
      option('배터리',bf,ba1,ba2,'Ah',(v)=>bf=v),
      option('태양광',sf,so1,so2,'W',(v)=>sf=v),
      option('인버터',inf,inv1,inv2,'W',(v)=>inf=v),
      option('주행충전기',af,alt1,alt2,'A',(v)=>af=v),
      DropdownButtonFormField<bool?>(initialValue:sh,decoration:const InputDecoration(labelText:'한전충전',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:null,child:Text('전체')),DropdownMenuItem(value:true,child:Text('있음')),DropdownMenuItem(value:false,child:Text('없음'))],onChanged:(v)=>ss(()=>sh=v)),const SizedBox(height:8),
      Row(children:[Expanded(child:select('청수',ff,const ['전체','없음','있음'],(v)=>ss(()=>ff=v))),if(ff=='있음')...[const SizedBox(width:6),Expanded(child:TextField(controller:fr,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'용량',suffixText:'리터 이상',border:OutlineInputBorder())))]]),const SizedBox(height:8),
      Row(children:[Expanded(child:select('오수',gf,const ['전체','없음','있음'],(v)=>ss(()=>gf=v))),if(gf=='있음')...[const SizedBox(width:6),Expanded(child:TextField(controller:gr,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'용량',suffixText:'리터 이상',border:OutlineInputBorder())))]]),const SizedBox(height:8),
      Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:tt,decoration:const InputDecoration(labelText:'화장실타입',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'전체',child:Text('전체')),DropdownMenuItem(value:'none',child:Text('없음')),DropdownMenuItem(value:'cassette',child:Text('카트리지')),DropdownMenuItem(value:'black',child:Text('블랙'))],onChanged:(v)=>ss(()=>tt=v!))),if(tt=='cassette'||tt=='black')...[const SizedBox(width:6),Expanded(child:TextField(controller:tc,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'용량',suffixText:'리터 이상',border:OutlineInputBorder())))]]),const SizedBox(height:12),
      FilledButton(onPressed:(){setState((){status=st;region=reg;priceFilter=pf;yearFilter=yf;batteryFilter=bf;solarFilter=sf;inverterFilter=inf;alternatorFilter=af;toilet=tt;freshFilter=ff;greyFilter=gf;shore=sh;minPrice=pf=='금액설정'?int.tryParse(a.text):null;maxPrice=pf=='금액설정'?int.tryParse(b.text):null;minYear=yf=='연식설정'?int.tryParse(y1.text):null;maxYear=yf=='연식설정'?int.tryParse(y2.text):null;maxKm=int.tryParse(km.text);minBattery=bf=='있음'?int.tryParse(ba1.text):null;maxBattery=bf=='있음'?int.tryParse(ba2.text):null;minSolar=sf=='있음'?int.tryParse(so1.text):null;maxSolar=sf=='있음'?int.tryParse(so2.text):null;minInverter=inf=='있음'?int.tryParse(inv1.text):null;maxInverter=inf=='있음'?int.tryParse(inv2.text):null;minAlternator=af=='있음'?int.tryParse(alt1.text):null;maxAlternator=af=='있음'?int.tryParse(alt2.text):null;minFresh=ff=='있음'?int.tryParse(fr.text):null;minGrey=gf=='있음'?int.tryParse(gr.text):null;minToilet=(tt=='cassette'||tt=='black')?int.tryParse(tc.text):null;});Navigator.pop(ctx);},child:const Text('적용'))
    ])))));}));
  }

  Future<void> edit([Map<String,dynamic>? x]) async {
    final isEdit=x!=null; TextEditingController c(String k)=>TextEditingController(text:'${x?[k]??''}');
    final t=c('title'),maker=c('manufacturer'),model=c('model'),year=c('model_year'),km=c('mileage_km'),price=c('price_krw'),rg=c('region'),phone=c('phone'),desc=c('description'),battery=c('battery_ah'),solar=c('solar_w'),inverter=c('inverter_w'),alternator=c('alternator_charger_a'),fresh=c('fresh_water_l'),grey=c('grey_water_l'),tc=c('toilet_capacity_l');
    bool hasBattery=x?['battery_ah']!=null,hasSolar=x?['solar_w']!=null,hasInverter=x?['inverter_w']!=null,hasAlternator=x?['alternator_charger_a']!=null,hasFresh=x?['fresh_water_l']!=null,hasGrey=x?['grey_water_l']!=null,shorePower=x?['shore_power']==true; String tt='${x?['toilet_type']??'none'}'; final photos=<XFile>[];
    final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,ss)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,0,16,MediaQuery.of(ctx).viewInsets.bottom+12),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(isEdit?'중고 캠핑카 수정':'중고 캠핑카 등록',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),TextField(controller:t,decoration:const InputDecoration(labelText:'매물 제목 *',border:OutlineInputBorder())),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:maker,decoration:const InputDecoration(labelText:'제조사',border:OutlineInputBorder()))),const SizedBox(width:6),Expanded(child:TextField(controller:model,decoration:const InputDecoration(labelText:'모델명 *',border:OutlineInputBorder())))]),const SizedBox(height:8),
      Row(children:[Expanded(child:num(year,'연식','년')),const SizedBox(width:6),Expanded(child:num(km,'주행거리','km'))]),const SizedBox(height:8),num(price,'판매가격','원'),const SizedBox(height:8),TextField(controller:rg,decoration:const InputDecoration(labelText:'판매지역 *',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:phone,decoration:const InputDecoration(labelText:'연락처 *',border:OutlineInputBorder())),const Divider(),
      _optionRow('배터리',hasBattery,(v)=>ss(()=>hasBattery=v),hasBattery?num(battery,'배터리','Ah'):null),_optionRow('태양광',hasSolar,(v)=>ss(()=>hasSolar=v),hasSolar?num(solar,'태양광','W'):null),_optionRow('인버터',hasInverter,(v)=>ss(()=>hasInverter=v),hasInverter?num(inverter,'인버터','W'):null),_optionRow('주행충전기',hasAlternator,(v)=>ss(()=>hasAlternator=v),hasAlternator?num(alternator,'주행충전기','A'):null),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('한전충전'),value:shorePower,onChanged:(v)=>ss(()=>shorePower=v)),_optionRow('청수',hasFresh,(v)=>ss(()=>hasFresh=v),hasFresh?TextField(controller:fresh,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'청수 용량',suffixText:'리터',border:OutlineInputBorder())):null),_optionRow('오수',hasGrey,(v)=>ss(()=>hasGrey=v),hasGrey?TextField(controller:grey,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'오수 용량',suffixText:'리터',border:OutlineInputBorder())):null),
      Row(children:[const Expanded(child:Text('화장실타입',style:TextStyle(fontWeight:FontWeight.w600))),Expanded(child:DropdownButtonFormField<String>(initialValue:tt,items:const [DropdownMenuItem(value:'none',child:Text('없음')),DropdownMenuItem(value:'cassette',child:Text('카트리지')),DropdownMenuItem(value:'black',child:Text('블랙'))],onChanged:(v)=>ss(()=>tt=v!)))]),if(tt=='cassette'||tt=='black')Padding(padding:const EdgeInsets.only(top:8),child:TextField(controller:tc,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'화장실 용량',suffixText:'리터',border:OutlineInputBorder()))),const SizedBox(height:8),TextField(controller:desc,maxLines:4,decoration:const InputDecoration(labelText:'기타 옵션 / 차량 설명',border:OutlineInputBorder())),const SizedBox(height:8),
      OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:20);ss((){photos.clear();photos.addAll(p.take(20));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/20')),if(isEdit)const Text('새 사진을 선택하면 기존 사진에 추가됩니다.',style:TextStyle(fontSize:12)),const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(isEdit?'수정 저장':'매물 등록'))
    ]))))));
    if(ok!=true)return; if(t.text.trim().isEmpty||model.text.trim().isEmpty||rg.text.trim().isEmpty||phone.text.trim().isEmpty){msg('필수 항목을 입력해주세요.');return;}
    try{final old=List<String>.from(x?['image_urls']??const []),urls=photos.isEmpty?old:[...old,...await upload(photos)];if(urls.length>20){msg('사진은 최대 20장입니다.');return;}final data={'title':t.text.trim(),'manufacturer':maker.text.trim(),'model':model.text.trim(),'model_year':int.tryParse(year.text),'mileage_km':int.tryParse(km.text),'price_krw':int.tryParse(price.text),'region':rg.text.trim(),'phone':phone.text.trim(),'description':desc.text.trim(),'battery_ah':hasBattery?int.tryParse(battery.text):null,'solar_w':hasSolar?int.tryParse(solar.text):null,'inverter_w':hasInverter?int.tryParse(inverter.text):null,'alternator_charger_a':hasAlternator?int.tryParse(alternator.text):null,'fresh_water_l':hasFresh?int.tryParse(fresh.text):null,'grey_water_l':hasGrey?int.tryParse(grey.text):null,'toilet_type':tt,'toilet_capacity_l':tt=='none'?null:int.tryParse(tc.text),'shore_power':shorePower,'image_urls':urls};if(isEdit){await db.from('vehicle_market_listings').update(data).eq('id',x['id']);}else{await db.from('vehicle_market_listings').insert({...data,'owner_id':uid,'status':'active'});}await load();msg(isEdit?'수정했습니다.':'등록했습니다.');}catch(e){msg('저장 실패: $e');}
  }

  Widget _optionRow(String label,bool enabled,ValueChanged<bool> changed,Widget? field)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Column(children:[SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(label),subtitle:Text(enabled?'있음':'없음'),value:enabled,onChanged:changed),if(field!=null)field]));
  Future<void> ownerAction(Map<String,dynamic>x,String v) async {if(v=='edit'){await edit(x);return;}if(v=='sold'){await db.from('vehicle_market_listings').update({'status':'sold'}).eq('id',x['id']);}else if(v=='active'){await db.from('vehicle_market_listings').update({'status':'active'}).eq('id',x['id']);}else if(v=='delete'){await db.from('vehicle_market_listings').delete().eq('id',x['id']);}await load();}
  Future<void> report(Map<String,dynamic>x) async {final c=TextEditingController();final photos=<XFile>[];final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,ss)=>AlertDialog(title:const Text('매물 신고'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,maxLength:500,maxLines:4,decoration:const InputDecoration(labelText:'신고 사유',border:OutlineInputBorder())),const SizedBox(height:8),OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:82,limit:10);ss((){photos.clear();photos.addAll(p.take(10));});},icon:const Icon(Icons.photo_library),label:Text('사진 첨부 ${photos.length}/10'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('신고'))])));if(ok==true&&c.text.trim().isNotEmpty){try{final urls=<String>[];for(var i=0;i<photos.length;i++){final path='$uid/report_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';await db.storage.from('vehicle-market').upload(path,File(photos[i].path),fileOptions:const FileOptions(upsert:false));urls.add(db.storage.from('vehicle-market').getPublicUrl(path));}await db.from('vehicle_market_reports').insert({'listing_id':x['id'],'reporter_id':uid,'reason':c.text.trim(),'photo_urls':urls});msg('신고가 접수되었습니다.');}catch(e){msg('이미 신고했거나 접수에 실패했습니다.');}}}
  Widget adSlot()=>Card(margin:const EdgeInsets.all(12),child:Container(height:72,alignment:Alignment.center,child:const Text('광고 영역',style:TextStyle(fontWeight:FontWeight.bold))));

  Future<void> _openMarketPhotos(List<String> photos,int initial) async {
    if(photos.isEmpty)return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(viewerContext){
      return Scaffold(
        backgroundColor:Colors.black,
        appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:const Text('중고차 사진')),
        body:PageView.builder(
          controller:PageController(initialPage:initial),
          itemCount:photos.length,
          itemBuilder:(pageContext,i)=>InteractiveViewer(
            minScale:1,
            maxScale:5,
            child:Center(child:Image.network(photos[i],fit:BoxFit.contain,errorBuilder:(context,error,stackTrace)=>const Icon(Icons.broken_image,color:Colors.white,size:64))),
          ),
        ),
      );
    }));
  }

  Future<void> detail(Map<String,dynamic>x) async {
    final photos=List<String>.from(x['image_urls']??const []),mine=x['owner_id']==uid;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(photos.isNotEmpty)SizedBox(height:220,child:PageView.builder(itemCount:photos.length,itemBuilder:(_,i)=>GestureDetector(onTap:()=>_openMarketPhotos(photos,i),child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(photos[i],fit:BoxFit.cover))))),const SizedBox(height:10),Row(children:[Expanded(child:Text('${x['title']}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold))),Chip(label:Text(x['status']=='sold'?'판매완료':'판매중'))]),Text('${x['manufacturer']} ${x['model']} · ${x['model_year']??'-'}년'),Text('주행거리 ${x['mileage_km']??'-'}km · ${x['region']}'),Text(money(x['price_krw']),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Divider(),
      Text('배터리 ${x['battery_ah']??'없음'}Ah · 태양광 ${x['solar_w']??'없음'}W'),Text('인버터 ${x['inverter_w']??'없음'}W · 주행충전 ${x['alternator_charger_a']??'없음'}A'),Text('한전충전 ${x['shore_power']==true?'있음':'없음'} · 청수 ${x['fresh_water_l']??'없음'}L · 오수 ${x['grey_water_l']??'없음'}L'),Text('화장실 ${x['toilet_type']=='cassette'?'카트리지':x['toilet_type']=='black'?'블랙':'없음'} ${x['toilet_capacity_l']??''}${x['toilet_capacity_l']!=null?'L':''}'),if('${x['description']??''}'.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('${x['description']}')),const SizedBox(height:10),Text('연락처: ${x['phone']}'),const SizedBox(height:12),
      if(mine)Wrap(spacing:8,children:[OutlinedButton(onPressed:(){Navigator.pop(ctx);edit(x);},child:const Text('수정')),OutlinedButton(onPressed:(){Navigator.pop(ctx);ownerAction(x,x['status']=='sold'?'active':'sold');},child:Text(x['status']=='sold'?'판매중으로 변경':'판매완료')),TextButton(onPressed:(){Navigator.pop(ctx);ownerAction(x,'delete');},child:const Text('삭제'))]) else OutlinedButton.icon(onPressed:()=>report(x),icon:const Icon(Icons.report_outlined),label:const Text('매물 신고'))
    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final r=filtered,total=r.length+(r.length~/10);
    return Scaffold(
      appBar:AppBar(title:const Text('차량중고마켓')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:SearchBar(controller:search,hintText:'캠핑카, 모델명 검색',leading:const Icon(Icons.search),onChanged:(v)=>setState(()=>q=v.trim()))),const SizedBox(width:8),IconButton.filledTonal(onPressed:filters,icon:const Icon(Icons.tune))])),
        Expanded(
          child: loading
              ? const Center(child:CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh:load,
                  child:r.isEmpty
                      ? ListView(children:const [SizedBox(height:180),Center(child:Text('조건에 맞는 매물이 없습니다.'))])
                      : ListView.builder(
                          padding:const EdgeInsets.only(bottom:110),
                          itemCount:total,
                          itemBuilder:(_,i){
                            if((i+1)%11==0)return adSlot();
                            final idx=i-(i~/11);
                            if(idx>=r.length)return const SizedBox.shrink();
                            final x=r[idx],photos=List<String>.from(x['image_urls']??const []);
                            return Card(
                              margin:const EdgeInsets.fromLTRB(12,5,12,5),
                              child:ListTile(
                                leading:photos.isEmpty?const CircleAvatar(child:Icon(Icons.directions_car)):ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.network(photos.first,width:64,height:64,fit:BoxFit.cover)),
                                title:Row(children:[Expanded(child:Text('${x['title']}')),if(x['status']=='sold')const Chip(label:Text('판매완료'))]),
                                subtitle:Text('${x['manufacturer']} ${x['model']} · ${x['model_year']??'-'}년\n${x['region']} · ${money(x['price_krw'])}'),
                                isThreeLine:true,
                                onTap:()=>detail(x),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ]),
      floatingActionButtonLocation:FloatingActionButtonLocation.endFloat,
      floatingActionButton:SafeArea(minimum:const EdgeInsets.only(bottom:72),child:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('매물 등록'))),
    );
  }
}
