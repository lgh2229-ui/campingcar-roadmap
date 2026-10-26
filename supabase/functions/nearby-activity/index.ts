import { createClient } from "npm:@supabase/supabase-js@2.49.10";

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Content-Type": "application/json; charset=utf-8" };
const RANGE = 3000;
type AnyObj = Record<string, any>;
const selectors: Record<string, string[]> = {
  // Include named natural scenic sites and suspension bridges, not just businesses.
  // Water polygon centers are informational; they are not public entry points.
  "관광지": ['["tourism"~"^(attraction|museum|viewpoint|zoo|aquarium|gallery)$"]',
    '["historic"]','["natural"="water"]["water"~"^(lake|reservoir)$"]["name"]',
    '["man_made"="bridge"]["name"~"출렁다리|구름다리"]',
    '["leisure"="park"]["name"]'],
  "산책": ['["leisure"~"^(park|garden|nature_reserve)$"]','["highway"~"^(path|footway|pedestrian|steps)$"]["name"]','["route"="foot"]','["tourism"="viewpoint"]'],
  "등산": ['["route"="hiking"]', '["natural"="peak"]', '["information"="guidepost"]'],
  "낚시": ['["sport"="fishing"]','["fishing"]','["leisure"="fishing"]',
   '["man_made"~"^(breakwater|pier)$"]["name"]','["harbour"]["name"]',
   '["seamark:type"="harbour"]["name"]','["man_made"="quay"]["name"]'],
  "해루질": ['["natural"~"^(beach|mud)$"]','["wetland"="tidalflat"]',
   '["natural"="wetland"]["wetland"~"^(tidalflat|saltmarsh)$"]',
   '["tourism"="attraction"]["name"~"갯벌|해루질|맛조개|바지락|동죽|조개잡이|어촌체험"]',
   '["name"~"맛조개|바지락|조개잡이|갯벌체험|해루질"]'],
  // Unified swimming, surfing, snorkeling, kayaking and SUP venues.
  // Open water is a candidate location, not proof that entering the water is allowed.
  "수상레포츠": ['["sport"~"^(sailing|surfing|canoe|kayaking|kitesurfing|scuba_diving|windsurfing|swimming|snorkeling|stand_up_paddle)$"]',
    '["leisure"~"^(marina|swimming_pool|water_park|swimming_area|bathing_place)$"]','["shop"="surf"]','["canoe"]',
    '["natural"="beach"]["name"]','["waterway"~"^(river|stream)$"]["name"~"물놀이|계곡|수영"]',
    '["tourism"="attraction"]["name"~"물놀이|계곡"]'],
  // Land sports includes golf, cycling, skiing and sledding.
  "지상레포츠": ['["sport"~"^(climbing|paragliding|archery|motocross|skateboard|horse_racing|skiing|golf|cycling)$"]',
    '["leisure"~"^(sports_centre|golf_course)$"]','["route"="bicycle"]','["highway"="cycleway"]["name"]',
    '["piste:type"]','["name"~"눈썰매|썰매장|스키장|파크골프|자전거체험|MTB"]'],
  "카지노": ['["amenity"="casino"]'],
  // Waterways are water-play candidates, NOT proof that entry is allowed.
  "온천·스파": ['["amenity"="public_bath"]','["leisure"="spa"]','["natural"="hot_spring"]'],
  "문화체험": ['["tourism"~"^(museum|gallery)$"]','["amenity"~"^(arts_centre|theatre|community_centre)$"]'],
  // Seafood retail and boat markets are part of market/shopping.
  "시장·쇼핑": ['["amenity"="marketplace"]',
   '["shop"~"^(fishmonger|seafood|supermarket|mall|department_store)$"]',
   '["tourism"="attraction"]["name"~"선상어시장|수산시장|직매장|어판장|선상횟집"]'],
};
const json = (obj: unknown, status=200) => new Response(JSON.stringify(obj),{status, headers:CORS});
function distanceM(a:number,b:number,c:number,d:number) {
 const r=(x:number)=>x*Math.PI/180;
 const dl=r(c-a),dn=r(d-b);
 const h=Math.sin(dl/2)**2+Math.cos(r(a))*Math.cos(r(c))*Math.sin(dn/2)**2;
 return 12742000*Math.atan2(Math.sqrt(h), Math.sqrt(1-h));
}
function label(t:AnyObj, activity:string) {
 if(t["shop"]==="fishing")return "낚시용품점 (선상낚시 업체 확인 필요)";
 if(t["sport"]==="fishing" || t["fishing"])return "낚시 관련 장소";
 if(activity==="해루질")return "갯벌·해변 후보 (채취 허가 여부 미확인)";
 if(t["tourism"]==="viewpoint")return "전망대";
 if(t["leisure"]==="park")return "공원";
 if(t["natural"]==="water" && /^(lake|reservoir)$/.test(String(t["water"]||"")))return "호수·저수지 (입구·출입 제한 별도 확인)";
 if(t["man_made"]==="bridge" && /출렁다리|구름다리/.test(String(t.name||"")))return "출렁다리";
 if(t["natural"]==="peak")return "산·봉우리";
 if(t["amenity"]==="casino")return "카지노";
 if(t["leisure"]==="marina")return "마리나";
 if(activity==="수상레포츠" && (t["waterway"]||t["natural"]==="beach"||t["tourism"]==="attraction"))
  return "강·계곡 물놀이 후보 (안전·출입 미확인)";
 return [t.tourism,t.leisure,t.sport,t.shop,t.amenity,t.historic].find(Boolean) || "주변 활동 장소";
}
// An explicit POI search is best-effort; unavailable public endpoints must never
// prevent results already checked and stored in our own database from displaying.
async function overpass(lat:number, lon:number, keys:string[]) {
 const query='[out:json][timeout:15];('+keys.map(k=>'nwr(around:'+RANGE+','+lat+','+lon+')'+k+';').join('')+');out center 120;';
 const urls=[
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass-api.de/api/interpreter',
 ];
 let lastError='';
 for(const url of urls) {
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),5500);
  try {
   // GET avoids several public proxies rejecting form-encoded POST with HTTP 406.
   const response=await fetch(url+'?data='+encodeURIComponent(query),{
     headers:{'Accept':'application/json','User-Agent':'CampingcarRoadmap/1.0'},
     signal:controller.signal});
   if(!response.ok) {lastError='HTTP '+response.status;continue;}
   const data=await response.json();
   if(Array.isArray(data.elements))return data.elements as AnyObj[];
   lastError='unexpected data';
  }catch(e){lastError=String(e);}finally{clearTimeout(timer);}
 }
 throw new Error('공개 지도 서버 일시 중단 ('+lastError.slice(0,80)+')');
}
// A search result is not proof of recreation; accommodation is never a public sport venue.
function matchesActivityTheme(activity:string,nameValue:unknown,kindValue:unknown=''):boolean{
 const name=String(nameValue||'').trim(),kind=String(kindValue||'').trim();
 if(!name)return false;
 if(/펜션|풀빌라|호텔|모텔|민박|리조트|게스트하우스|호스텔|여관|숙박|카라반|글램핑|콘도|스테이(?:$|\\s)/i.test(name) ||
    /(^|[>\\s])숙박([>\\s]|$)|펜션|풀빌라|호텔|모텔|리조트|게스트하우스/i.test(kind))return false;
 if(activity==='수상레포츠'){
  return /해수욕장|해변|비치|beach|서핑|서프|카약|카누|SUP|패들보드|스탠드업패들|스노클|스노쿨|수영|해수욕|물놀이|워터파크|수상레저|수상스포츠|해양레저|다이빙|스쿠버|요트|제트스키|수상스키|웨이크보드|래프팅|마리나|보트체험|바나나보트/i.test(name) ||
    /^(surfing|sailing|kayaking|canoe|swimming|snorkeling|scuba_diving|marina|water_park|bathing_place)$/i.test(kind);
 }
 return true;
}

function dedupeSpots(items:AnyObj[],lat:number,lon:number,activity:string):AnyObj[]{
 const unique:AnyObj[]=[];
 for(const raw of items){
  const p=normalizePlace(raw,lat,lon,activity);
  if(!p)continue;
  if(unique.some(old=>equivalentPlace(old.name,p.name)&&distanceM(old.lat,old.lon,p.lat,p.lon)<150))continue;
  unique.push(p);
 }
 return unique.sort((a,b)=>a.distance_m-b.distance_m).slice(0,25);
}
function validHttp(value:any):string {
 const text=String(value||'').trim();
 return (text.startsWith('https://')||text.startsWith('http://'))?text.slice(0,400):'';
}
function normalizePlace(item:AnyObj,lat:number,lon:number,activity:string) {
 const a=Number(item.lat),b=Number(item.lon);
 if(!Number.isFinite(a)||!Number.isFinite(b))return null;
 const distance_m=Math.round(distanceM(lat,lon,a,b));
 if(distance_m>RANGE)return null;
 const name=String(item.name||'').trim().slice(0,130);
 if(!name || !matchesActivityTheme(activity,name,item.kind||''))return null;
 return {
  name,lat:a,lon:b,distance_m,
  kind:String(item.kind||activity).slice(0,90),
  description:String(item.description||'').slice(0,320),
  address:String(item.address||'').slice(0,170),
  phone:String(item.phone||'').slice(0,80),
  website:validHttp(item.website),
  opening_hours:String(item.opening_hours||'').slice(0,140),
  fee:String(item.fee||'').slice(0,70),
  source_url:validHttp(item.source_url),
  photo_hint:String(item.photo_hint||'').startsWith('File:')?String(item.photo_hint).slice(0,200):'',
 };
}
async function curatedPoi(db:any,lat:number,lon:number,activity:string){
 const latDelta=RANGE/110570,lonDelta=RANGE/(111320*Math.max(0.2,Math.cos(lat*Math.PI/180)));
 const {data,error}=await db.from('verified_activity_pois').select('*')
  .eq('activity',activity)
  .gte('latitude',lat-latDelta).lte('latitude',lat+latDelta)
  .gte('longitude',lon-lonDelta).lte('longitude',lon+lonDelta).limit(75);
 if(error)throw error;
 let matches=(data||[]) as AnyObj[];
 // Merge cross-listed coastal places even if some primary POIs are present.
 {
  const {data:related,error:relatedError}=await db.from('verified_activity_pois').select('*')
   .contains('related_activities',[activity])
   .gte('latitude',lat-latDelta).lte('latitude',lat+latDelta)
   .gte('longitude',lon-lonDelta).lte('longitude',lon+lonDelta).limit(75);
  if(relatedError)console.warn('related activity:',String(relatedError.message).slice(0,80));
  else matches=[...matches,...(related||[]).filter((p:AnyObj)=>!matches.some(x=>x.poi_key===p.poi_key))] as AnyObj[];
 }
 const mapped=matches.map((p:AnyObj)=>normalizePlace({
  name:p.name,lat:p.latitude,lon:p.longitude,kind:activity,
  description:p.description,phone:p.phone,website:p.info_source_url,
  source_url:p.info_source_url||p.map_source_url,
 },lat,lon,activity)).filter(Boolean) as AnyObj[];
 // Aquatic POIs from overlapping surf/water feeds can share a location.
 // Keep the specific venue name while suppressing a second identical pin.
 if(activity==='수상레포츠'){
  const unique=new Map<string,AnyObj>();
  for(const p of mapped){
   const key=Number(p.lat).toFixed(5)+'/'+Number(p.lon).toFixed(5);
   const old=unique.get(key);
   if(!old || (/수상레포츠/.test(String(old.name)) && !/수상레포츠/.test(String(p.name)))) unique.set(key,p);
  }
  return [...unique.values()];
 }
 return mapped;
}
// Search the names people actually use, not just abstract category labels.
const searchTerms:Record<string,string[]>={
 '관광지':['해수욕장','관광명소','호수','저수지','출렁다리','수변길','관광공원','전망대','관광지'],
 '산책':['산책로','수변공원','둘레길','해안길','벽화골목'],
 '등산':['등산로','등산','둘레길'],
 '낚시':['낚시포인트','선착장','방파제','낚시터','항구','포구','워킹낚시'],
 '해루질':['맛조개','맛조개잡이','조개잡이','갯벌체험','해루질','바지락','동죽','백합','낙지','소라','꽃게','어촌체험','조개채취','갯벌'],
 '수상레포츠':['수상레저','서핑','서핑샵','수영장','물놀이장','계곡 물놀이','해수욕장','스노클링','카약','SUP','다이빙'],
 '지상레포츠':['골프장','파크골프','자전거체험','자전거길','스키장','눈썰매장','짚라인','스카이사이클','ATV','레포츠'],
 '카지노':['카지노'],
 '온천·스파':['온천','스파','목욕탕'],
 '문화체험':['문화체험','박물관','문화마을'],
 '시장·쇼핑':['수산물직매장','선상어시장','선상횟집','수산물센터','어시장','수산시장','어판장','전통시장','마트','시장']
};
const discoveryKeywords:Record<string,string>=Object.fromEntries(
 Object.entries(searchTerms).map(([key,terms])=>[key,terms[0]]));

const SEARCH_VERSION=14;
const EMPTY_RETRY_MS=6*60*60*1000;
const KTO_SOURCE='https://www.data.go.kr/data/15101578/openapi.do';
function tourActivity(item:AnyObj):string|null{
 const type=String(item.contenttypeid||'');
 const name=String(item.title||'').toLowerCase();
 if(/캠핑|야영|글램핑|카라반|오토캠프/.test(name))return null;
 if(['12','14','15','25'].includes(type)){
  if(type==='14')return '문화체험';
  if(/낚시/.test(name))return '낚시';
  if(/해루질|갯벌|조개잡이|맛조개|바지락|동죽|백합|어촌체험/.test(name))return '해루질';
  if(/등산|등반|산행/.test(name))return '등산';
  if(/산책|둘레길|해안길|탐방로|트레킹/.test(name))return '산책';
  return '관광지';
 }
 if(type==='38')return '시장·쇼핑';
 if(type!=='28')return null;
 if(/낚시/.test(name))return '낚시';
 if(/해루질|갯벌|조개잡이|맛조개|바지락|동죽|백합|어촌체험/.test(name))return '해루질';
 if(/서핑|서프|카약|카누|스노클|스노쿨|수영|물놀이|요트|수상|래프팅|sup/.test(name))return '수상레포츠';
 if(/산책|둘레길|탐방로|트레킹/.test(name))return '산책';
 if(/등산|등반|산행/.test(name))return '등산';
 return '지상레포츠';
}
// Query the tourism authority live; a one-off admin importer is not live search.
async function tourApiSearch(lat:number,lon:number,activity:string):Promise<AnyObj[]>{
 let key=Deno.env.get('KTO_TOUR_API_KEY')||'';
 if(!key)throw new Error('KTO_API_KEY_NOT_CONFIGURED');
 if(key.includes('%')){try{key=decodeURIComponent(key);}catch(_){}}
 const results:AnyObj[]=[];
 for(let page=1;page<=2;page++){
  const url=new URL('https://apis.data.go.kr/B551011/KorService2/locationBasedList2');
  for(const [field,value] of Object.entries({
   serviceKey:key,MobileOS:'ETC',MobileApp:'CampingcarRoadmap',_type:'json',
   mapX:String(lon),mapY:String(lat),radius:String(RANGE),
   arrange:'E',numOfRows:'100',pageNo:String(page)
  }))url.searchParams.set(field,value);
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),8500);
  try{
   const response=await fetch(url.toString(),{headers:{Accept:'application/json'},signal:controller.signal});
   if(!response.ok)throw new Error('KTO HTTP '+response.status);
   const payload=await response.json();
   const body=payload?.response?.body, header=payload?.response?.header;
   if(String(header?.resultCode??'0000')!=='0000')throw new Error('KTO_RESULT_'+header.resultCode);
   const raw=body?.items?.item||[];
   const items=Array.isArray(raw)?raw:[raw];
   for(const item of items){
    const classified=tourActivity(item);
    if(classified!==activity && !(activity==='관광지' && String(item.contenttypeid)==='14'))continue;
    const name=String(item.title||'').replace(/<[^>]*>/g,' ').trim();
    const id=String(item.contentid||'').trim();
    const poi=normalizePlace({
      name,lat:item.mapy,lon:item.mapx,kind:activity,
      address:String(item.addr1||'').slice(0,160),phone:String(item.tel||'').replace(/<[^>]*>/g,' ').trim(),
      description:'한국관광공사 관광정보 '+(id?'(ID '+id+')':'')+'. 실제 이용·운영조건 별도 확인.',
      source_url:KTO_SOURCE
    },lat,lon,activity);
    if(poi)results.push(poi);
   }
   if(items.length<100 || page*100>=Number(body?.totalCount||0))break;
  }finally{clearTimeout(timer);}
 }
 return results;
}

// Extract the geographic area rather than treating a campsite's brand,
// lot number or sector as the destination people use in tourism blog searches.
function geographicRoots(full:string):string[]{
 const name=full.replace(/\s+/g,'').trim();
 const root=name
  .replace(/(?:제?[0-9]+(?:구역|지구|캠핑존|사이트|호))$/g,'')
  .replace(/(?:오토캠핑장|감성캠핑장|캠핑장|야영장|오토캠핑|캠핑|공영주차장|해변주차장|주차장|선착장|방파제|물양장|낚시터|노지|차박|매표소|입구).*$/,'')
  .replace(/(?:오토|감성)$/,'').trim();
 const withPlace=name.replace(/(?:제?[0-9]+(?:구역|지구|캠핑존|사이트|호))$/g,'')
  .replace(/(?:오토캠핑장|감성캠핑장|캠핑장|야영장|오토캠핑|캠핑|공영주차장|주차장).*$/,'').trim();
 const items=[root,withPlace];
 // Ports sometimes also contain a beach, but do not infer actual harvesting.
 if(/포$/.test(root))items.push(root+'해수욕장');
 if(/해수욕장|해변|포구|항/.test(root))items.push(root.replace(/(해수욕장|해변|포구|항)$/,''));
 return [...new Set(items.filter(x=>x.length>=2&&x.length<=35))].slice(0,3);
}

// Search snippets are supporting evidence, never proof of an exact map pin.
async function naverBlogEvidence(placeName:string,activity:string):Promise<AnyObj[]>{
 if(activity!=='해루질' && activity!=='낚시')return [];
 const clientId=Deno.env.get('NAVER_SEARCH_CLIENT_ID')||'';
 const clientSecret=Deno.env.get('NAVER_SEARCH_CLIENT_SECRET')||'';
 if(!clientId||!clientSecret)throw new Error('NAVER_SEARCH_CREDENTIALS_MISSING');
 const areas=geographicRoots(placeName);
 const queries=[...new Set(areas.flatMap(area=>activity==='낚시'
  ? [area+' 낚시 포인트',area+' 선착장 원투 루어']
  : [area+' 맛조개',area+' 갯벌체험 해루질']))].slice(0,4);
 const responses=await Promise.allSettled(queries.map(async query=>{
  const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),3200);
  try{
   const url='https://openapi.naver.com/v1/search/blog.json?'+new URLSearchParams({query,display:'10',sort:'sim'});
   const result=await fetch(url,{headers:{'X-Naver-Client-Id':clientId,'X-Naver-Client-Secret':clientSecret},signal:controller.signal});
   if(!result.ok)throw new Error('NAVER_SEARCH_'+result.status);
   const body=await result.json();
   return (Array.isArray(body.items)?body.items:[]).map((x:AnyObj)=>({
    name:String(x.title||'').replace(/<[^>]*>/g,' ').slice(0,110),
    source_url:validHttp(x.link),
    description:String(x.description||'').replace(/<[^>]*>/g,' ').slice(0,230),
    published_at:String(x.postdate||'').slice(0,8),
    location_verified:false,
    note:'관련 블로그 문서입니다. 정확한 활동 위치와 현재 출입·낚시·채취 허가를 검증하지 않았습니다.'
   })).filter((x:AnyObj)=>x.source_url&&
     (activity==='낚시'
  ? /낚시|원투|루어|방파제|조황|갯바위|찌낚시/.test(x.name+' '+x.description)
  : /맛조개|조개|갯벌|해루질|동죽|바지락/.test(x.name+' '+x.description))&&
     areas.some(area=>(x.name+' '+x.description).replace(/\s+/g,'').includes(area.replace(/\s+/g,''))));
  }finally{clearTimeout(timeout);}
 }));
 if(responses.every(x=>x.status==='rejected'))throw new Error('NAVER_BLOG_SEARCH_UNAVAILABLE');
 const found=responses.flatMap(x=>x.status==='fulfilled'?x.value:[]);
 return [...new Map(found.map((x:AnyObj)=>[x.source_url,x])).values()].slice(0,6);
}

// YouTube is documentary evidence only. Video descriptions have no trusted GPS.
async function youtubeFishingEvidence(placeName:string,activity:string):Promise<AnyObj[]>{
 if(activity!=='낚시')return [];
 const key=Deno.env.get('YOUTUBE_DATA_API_KEY')||'';
 if(!key)throw new Error('YOUTUBE_DATA_API_KEY_NOT_CONFIGURED');
 const roots=geographicRoots(placeName),area=roots[0];
 if(!area)return [];
 const url='https://www.googleapis.com/youtube/v3/search?'+new URLSearchParams({
  part:'snippet',type:'video',q:area+' 방파제 선착장 낚시',maxResults:'10',
  regionCode:'KR',relevanceLanguage:'ko',key
 });
 const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),4500);
 try{
  const response=await fetch(url,{signal:controller.signal});
  if(!response.ok)throw new Error('YOUTUBE_SEARCH_'+response.status);
  const data=await response.json();
  return (Array.isArray(data.items)?data.items:[])
   .map((item:AnyObj)=>({
    name:String(item.snippet?.title||'').slice(0,110),
    source_url:item.id?.videoId?'https://www.youtube.com/watch?v='+encodeURIComponent(String(item.id.videoId)):'',
    description:String(item.snippet?.description||'').slice(0,230),
    published_at:String(item.snippet?.publishedAt||''),
    location_verified:false,
    note:'관련 유튜브 영상입니다. 촬영 장소 세부 좌표·현재 출입과 낚시 허가를 확인하지 않았습니다.'
   }))
   .filter((item:AnyObj)=>item.source_url &&
      /낚시|원투|루어|조황|갯바위|방파제|선착장/.test(item.name+' '+item.description) &&
      roots.some(root=>(item.name+' '+item.description).replace(/\s+/g,'').includes(root.replace(/\s+/g,''))))
   .slice(0,6);
 }finally{clearTimeout(timeout);}
}

// A source naming the same registered port supports a port-level candidate pin,
// not a claim that a specific pier, tetrapod or restricted zone permits fishing.
function fishingPortAnchor(place:AnyObj,docs:AnyObj[],lat:number,lon:number):AnyObj|null{
 const name=String(place.name||'');
 if(!/(항|포구|선착장|방파제)/.test(name))return null;
 const roots=geographicRoots(name);
 const match=docs.find(d=>{
  const desc=(String(d.name||'')+' '+String(d.description||'')).replace(/\s+/g,'');
  return validHttp(d.source_url) &&
   roots.some(root=>root.length>=3&&/(항|포구)$/.test(root)&&desc.includes(root)) &&
   /낚시|원투|루어|조황|갯바위|방파제|선착장/.test(desc) &&
   !/낚시\s*금지|출입\s*금지|낚시금지/.test(desc);
 });
 if(!match)return null;
 return normalizePlace({
  name:(roots.find(root=>/(항|포구)$/.test(root))||name)+' 주변 낚시 정보 후보',
  lat,lon,kind:'항구 위치 확인 · 낚시 가능 구역/허가 미확인',
  description:'주변 낚시 사례를 공개 문서에서 발견했습니다. 표시 핀은 기존 항구의 대표 위치이며 실제 낚시 자리·허가를 확인한 것이 아닙니다.',
  source_url:match.source_url,website:match.source_url
 },lat,lon,'낚시');
}

async function kakaoSearch(lat:number,lon:number,activity:string,key:string|undefined,placeName='',placeAddress=''){
 if(!key)throw new Error('REGIONAL_MAP_KEY_NOT_CONFIGURED');
 const roots=geographicRoots(placeName);
 const root=roots[0]||placeName.slice(0,20);
 // Facility marketing names often hide nearby lakes, trails and local landmarks.
 // Geographic address terms provide an independent area-based search.
 const regionParts=String(placeAddress||'').match(/([가-힣]+(?:시|군|구))\s+([가-힣]+(?:읍|면|동))/);
 const region=regionParts?.[1]||'';
 const locality=regionParts?.[2]||'';
 const coastal=/항|포구|선착장|방파제|어촌|해변|해수욕장|해안/.test(root);
 const targeted=root && activity==='관광지'
  ? [root,root.replace(/국립공원$/,'')+' 해수욕장',root+' 주변 관광지',
     ...(region?[region+' 해수욕장',region+' 관광명소',region+' 호수',region+' 수변길',region+' 출렁다리',region+' 공원']:[]),
     ...(region&&locality?[region+' '+locality+' 관광지']:[])]
  : root && activity==='시장·쇼핑'
  ? (coastal?[root+' 수산물직매장',root+' 선상어시장',root+' 선상횟집']:[root+' 전통시장',root+' 마트'])
  : root && activity==='해루질'
  ? roots.flatMap(area=>[area+' 맛조개',area+' 조개잡이',area+' 갯벌체험',area+' 해루질'])
  : root && activity==='낚시'
  ? roots.flatMap(area=>[area+' 낚시',area+' 원투낚시',area+' 방파제 낚시',area+' 선착장'])
  : root && activity==='수상레포츠'
  ? [root.replace(/국립공원$/,'')+' 해수욕장',root+' 서핑',root+' 카약',...(region?[region+' 해수욕장']:[])] : [];
 const marketMix=['수산물직매장','전통시장','마트','수산시장','시장',
   '수산물센터','어시장','농산물직판장'];
 const count=activity==='관광지'?12:activity==='시장·쇼핑'?10:activity==='지상레포츠'?10:activity==='수상레포츠'?12:activity==='낚시'?10:activity==='해루질'?8:4;
 const terms=[...new Set([...targeted,...(activity==='시장·쇼핑'?marketMix:(searchTerms[activity]||[activity]))])].slice(0,count);
 const found:AnyObj[]=[];
 let successes=0, failures=0;
 // Parallel bounded batches: 10 sequential 3.5-second timeouts made searches stall.
 for(let batch=0;batch<terms.length;batch+=3){
  await Promise.all(terms.slice(batch,batch+3).map(async (term)=>{
  const url='https://dapi.kakao.com/v2/local/search/keyword.json?'+
    new URLSearchParams({query:term,x:String(lon),y:String(lat),radius:String(RANGE),size:'15',sort:'distance'});
  const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),activity==='시장·쇼핑'?2800:3500);
  try{
   const r=await fetch(url,{headers:{Authorization:'KakaoAK '+key},signal:ctrl.signal});
   if(!r.ok){failures++;return;}
   successes++;
   const data=await r.json();
   for(const d of data.documents||[]){
    if(activity==='관광지' &&
       !/관광|여행|명소|전망대|해변|해수욕장|수목원|공원|박물관|문화재|유적|축제|정원|미술관|테마파크|포토존|호수|저수지|수변길|둘레길|출렁다리|구름다리/i.test(
        String(d.category_name||'')+' '+String(d.place_name||'')))continue;
    if(activity==='해루질' &&
       !/갯벌|해루질|맛조개|바지락|동죽|백합|조개|어촌체험|체험마을|해변|해수욕장|해안|낙지|소라|꽃게/i.test(
         String(d.place_name||'')+' '+String(d.category_name||'')))continue;
    if(activity==='시장·쇼핑' &&
       !/수산|어시장|시장|직매장|어판장|선상|회뜨는|마트|쇼핑|상설|장터|활어|회센터|회센타/i.test(
        String(d.place_name||'')+' '+String(d.category_name||'')))continue;
    if(!matchesActivityTheme(activity,d.place_name,d.category_name))continue;
    const kind=activity==='낚시'&&/방파제|선착장|항구/.test(term)
      ? '낚시 관련 해안시설 후보 (출입·낚시 허용 여부 현장 확인)'
      : activity;
    const waterCandidate=activity==='수상레포츠' && /계곡|강변|하천|유원지|물놀이|해수욕장/i.test(String(d.place_name||''));
    const candidateKind=activity==='시장·쇼핑'
      ? '시장·직매장 관련 시설 (판매·영업 조건 확인)'
      : activity==='해루질'
      ? '갯벌·해루질 장소 후보 (채취·출입 허가 미확인)'
      : activity==='낚시'
      ? '낚시 관련 항만시설 후보 (출입·낚시 허가 미확인)'
      : waterCandidate?'강·계곡 물놀이 후보 (안전·출입 미확인)':kind;
    const spot=normalizePlace({name:d.place_name,lat:d.y,lon:d.x,kind:candidateKind,
      address:d.road_address_name||d.address_name,phone:d.phone,
      website:d.place_url,source_url:d.place_url,
      description:activity==='낚시'?
       '지도에 등록된 항만 관련 시설입니다. 낚시 가능 여부 및 출입통제 여부는 현장 확인이 필요합니다.':
       waterCandidate?
       '강·계곡 물놀이 관련 지도 장소 후보입니다. 실제 수영·입수 허용, 수심·급류·수질·출입 통제는 현장 안내를 확인하세요.':
       activity==='해루질'
        ? '지도에 등록된 갯벌·해루질 후보입니다. 실제 출입·채취 허가와 어촌계 관리, 갯골·물때를 확인하세요.'
        : activity==='시장·쇼핑'
          ? '시장·어시장·직매장 관련 지도 장소입니다. 판매 품목, 운영시간과 가격을 확인하세요.'
          : '지도에 등록된 주변 장소입니다.'
    },lat,lon,activity);
    if(spot&&!found.some(x=>x.name===spot.name))found.push(spot);
   }
  }catch(e){failures++;console.warn('Kakao keyword lookup:',String(e).slice(0,80));}
  finally{clearTimeout(timer);}
  }));
  if(found.length>=15 && activity!=='시장·쇼핑')break;
 }
 if(successes===0 && failures>0)throw new Error('REGIONAL_MAP_SEARCH_UNAVAILABLE');
 return found.slice(0,20);
}
async function nominatimSearch(lat:number,lon:number,activity:string,name:string){
 // Nominatim is a backup, not a bulk POI scraper. At most one bounded request.
 const latDelta=RANGE/110570,lonDelta=RANGE/(111320*Math.max(0.2,Math.cos(lat*Math.PI/180)));
 const tokens=name.replace(/(공영주차장|주차장|캠핑장|덤프스테이션|노지|후보|오토캠핑|자동차캠핑)/g,'').trim().slice(0,35);
 const query=(tokens+' '+(discoveryKeywords[activity]||activity)).trim();
 const url='https://nominatim.openstreetmap.org/search?'+new URLSearchParams({
  q:query,format:'jsonv2',addressdetails:'0',limit:'6',bounded:'1',
  viewbox:[lon-lonDelta,lat+latDelta,lon+lonDelta,lat-latDelta].join(','),
 });
 const ctrl=new AbortController(), timer=setTimeout(()=>ctrl.abort(),6500);
 try{
  const response=await fetch(url,{headers:{'Accept-Language':'ko','User-Agent':'CampingcarRoadmap/1.0'},signal:ctrl.signal});
  if(!response.ok)throw new Error('Nominatim '+response.status);
  const items=await response.json();
  return (Array.isArray(items)?items:[]).map((d:AnyObj)=>normalizePlace({
   name:d.name||String(d.display_name||'').split(',')[0],lat:d.lat,lon:d.lon,
   kind:activity,description:'공개지도 검색결과입니다. 세부 운영사항은 직접 확인하세요.',
   source_url:d.osm_type&&d.osm_id?'https://www.openstreetmap.org/'+
    ({N:'node',W:'way',R:'relation'}[String(d.osm_type).toUpperCase()]||d.osm_type)+'/'+d.osm_id:'',
  },lat,lon,activity)).filter(Boolean);
 }finally{clearTimeout(timer);}
}

function spotFromElement(e:AnyObj, lat:number,lon:number,activity:string) {
 const t=e.tags||{};
 const name=String(t['name:ko']||t.name||'').trim();
 const la=Number(e.lat??e.center?.lat),lo=Number(e.lon??e.center?.lon);
 if(!name || !Number.isFinite(la) || !Number.isFinite(lo) || !matchesActivityTheme(activity,name,label(t,activity)))return null;
 const meters=Math.round(distanceM(lat,lon,la,lo));
 if(meters>RANGE)return null;
 const url='https://www.openstreetmap.org/'+e.type+'/'+e.id;
 const phone=String(t['contact:phone']||t.phone||'').trim().slice(0,90);
 const website=String(t['contact:website']||t.website||'').trim();
 const safeWebsite=/^https?:\/\//i.test(website)?website:'';
 return {name,lat:la,lon:lo,distance_m:meters,kind:label(t,activity),address:String(t['addr:full']||t['addr:street']||'').slice(0,160),phone,website:safeWebsite,opening_hours:String(t.opening_hours||'').slice(0,120),fee:String(t.fee||'').slice(0,45),description:String(t['description:ko']||t.description||
   ((t.natural==='water' && /^(lake|reservoir)$/.test(String(t.water||'')))
     ? '호수·저수지의 지도 중심점입니다. 관광객 진입로·시설 개방·출입 가능 구역은 별도 확인하세요.' : '')||(
  activity==='수상레포츠' && (t.waterway||t.natural==='beach'||t.tourism==='attraction')
   ? '강·계곡·하천 물놀이 관련 지형 후보입니다. 수영 허용 여부, 급류·수심·수질·기상 상황을 현장에서 확인하세요.'
   : ''
 )).slice(0,250),source_url:url,photo_hint:String(t.wikimedia_commons||'').startsWith('File:')?String(t.wikimedia_commons):''};
}
// AI searches fresh public web sources only when a server-side API key is configured.
// It may enrich descriptions of independently geolocated POIs, but must not create
// map points or phone numbers from its own unverified text.
// No paid OpenAI summary. Display the verified place details and citations directly.
function metaText(x:unknown):string {
 return String(x||'').replace(/<[^>]*>/g,' ').replace(/&amp;/g,'&').replace(/\s+/g,' ').trim().slice(0,180);
}
// Photos are never AI-generated or sourced from arbitrary copyrighted images.
// Only Commons items with an actual CC/Public Domain licence may appear.
async function photoFor(spot:AnyObj):Promise<AnyObj|null>{
 const name=String(spot.name||'').trim(),hint=String(spot.photo_hint||'');
 if(!name||name.length<2)return null;
 const params=new URLSearchParams({
  action:'query',format:'json',
  prop:'imageinfo',iiprop:'url|extmetadata',iiurlwidth:'760'
 });
 if(hint.startsWith('File:'))params.set('titles',hint);
 else {
  params.set('generator','search');
  params.set('gsrsearch','intitle:"'+name.slice(0,35)+'"');
  params.set('gsrnamespace','6');
  params.set('gsrlimit','4');
 }
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),5000);
 try{
  const r=await fetch('https://commons.wikimedia.org/w/api.php?'+params.toString(),{
   headers:{'User-Agent':'CampingcarRoadmap/1.0','Accept':'application/json'},signal:ctrl.signal});
  if(!r.ok)return null;
  const data=await r.json();
  for(const page of Object.values(data.query?.pages||{}) as AnyObj[]){
   const title=String(page.title||'');
   if(!hint && !title.replace(/[\s_-]+/g,'').toLowerCase().includes(name.replace(/[\s_-]+/g,'').toLowerCase()))continue;
   const info=page.imageinfo?.[0],meta=info?.extmetadata||{};
   const license=metaText(meta.LicenseShortName?.value);
   if(!/(CC0|CC[-\s]*BY|public domain)/i.test(license))continue;
   const url=validHttp(info?.thumburl||info?.url);
   if(!(url.startsWith('https://upload.wikimedia.org/')||url.startsWith('https://thumb.wikimedia.org/')))continue;
   return {name:spot.name,url,thumbnail_url:url,source_url:'https://commons.wikimedia.org/wiki/'+encodeURIComponent(title.replace(/ /g,'_')),
    source_name:'Wikimedia Commons',license,attribution:metaText(meta.Artist?.value)||'출처에서 저작자 확인'};
  }
 }catch(e){console.warn('Commons image unavailable:',String(e).slice(0,90));}
 finally{clearTimeout(timer);}
 return null;
}
async function photoList(spots:AnyObj[]):Promise<AnyObj[]>{
 const items:AnyObj[]=[];
 for(const spot of spots.slice(0,3)){
  const p=await photoFor(spot);
  if(p && !items.some(x=>x.source_url===p.source_url))items.push(p);
 }
 return items;
}
// AI is only a candidate finder; locations must be independently re-geocoded.
// Paid initial AI candidate search removed. Only free/official sources are used.
function equivalentPlace(a:string,b:string):boolean{
 const n=(x:string)=>x.toLocaleLowerCase().replace(/[^\p{L}\p{N}]/gu,'');
 const x=n(a),y=n(b);
 if(x.length>=4 && y.length>=4 && (x.includes(y)||y.includes(x)))return true;
 const stop=/^(산책|레포츠|낚시|포인트|정보|체험|코스|시설|주변|해안|바다|내항|방파제|스카이|공원|관광지)$/;
 const words=(v:string)=>v.toLocaleLowerCase().split(/[\s,().-]+/g)
   .map(n).filter(t=>t.length>=3 && !stop.test(t));
 return words(a).some(t=>words(b).some(u=>t.length>=3 && u.length>=3 && (t===u || (t.length>=4 && u.length>=4&&(t.includes(u)||u.includes(t))))));
}
// Independent mapping source validates each suggested trailhead/place.
// Model-supplied coordinates are never used.
async function verifyCandidate(place:AnyObj,activity:string,candidate:AnyObj):Promise<AnyObj|null>{
 const lat=Number(place.latitude),lon=Number(place.longitude),name=String(candidate.name||'').trim();
 const kakao=Deno.env.get('KAKAO_REST_API_KEY');
 if(kakao){
  const u='https://dapi.kakao.com/v2/local/search/keyword.json?'+new URLSearchParams({
   query:name,x:String(lon),y:String(lat),radius:'3000',size:'6'});
  const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),6000);
  try{
   const r=await fetch(u,{headers:{Authorization:'KakaoAK '+kakao},signal:ctrl.signal});
   if(r.ok){
    const data=await r.json();
    for(const p of data.documents||[]){
     const actual=String(p.place_name||'').replace(/\s/g,'');
     const expected=name.replace(/\s/g,'');
     if(equivalentPlace(name,String(p.place_name||''))){
      const spot=normalizePlace({
       name:p.place_name,lat:p.y,lon:p.x,kind:activity,
       address:p.road_address_name||p.address_name,phone:p.phone,
       website:p.place_url,source_url:p.place_url,
       description:'AI 추가 웹검색 후 지도 좌표로 검증한 장소입니다.'},lat,lon,activity);
      if(spot)return spot;
     }
    }
   }
  }catch(_){}finally{clearTimeout(timer);}
 }
 const latD=RANGE/110570,lonD=RANGE/(111320*Math.max(.2,Math.cos(lat*Math.PI/180)));
 const url='https://nominatim.openstreetmap.org/search?'+new URLSearchParams({
  q:name,format:'jsonv2',limit:'5',bounded:'1',
  viewbox:[lon-lonD,lat+latD,lon+lonD,lat-latD].join(',')});
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),6000);
 try{
  const r=await fetch(url,{headers:{'Accept-Language':'ko','User-Agent':'CampingcarRoadmap/1.0'},signal:ctrl.signal});
  if(!r.ok)return null;
  const list=await r.json();
  for(const p of Array.isArray(list)?list:[]){
   const got=String(p.name||String(p.display_name||'').split(',')[0]).replace(/\s/g,'');
   const expected=name.replace(/\s/g,'');
   if(!got||!equivalentPlace(name,String(p.name||String(p.display_name||'').split(',')[0])))continue;
   const type=String(p.osm_type||'').toLowerCase();
   const source=type&&p.osm_id?'https://www.openstreetmap.org/'+
    ({n:'node',w:'way',r:'relation'}[type]||type)+'/'+p.osm_id:candidate.source_url;
   const spot=normalizePlace({name:p.name||name,lat:p.lat,lon:p.lon,
    kind:activity,source_url:source,description:'AI 웹검색 결과를 공개지도 좌표로 검증한 장소입니다.'},lat,lon,activity);
   if(spot)return spot;
  }
 }catch(_){}finally{clearTimeout(timer);}
 return null;
}

Deno.serve(async (req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:CORS});
 if(req.method!=='POST')return json({error:'POST only'},405);
 try {
  const token=req.headers.get('authorization')||'';
  if(!/^Bearer\s+\S+/i.test(token))return json({error:'로그인이 필요합니다.'},401);
  const url=Deno.env.get('SUPABASE_URL')||'',anon=Deno.env.get('SUPABASE_ANON_KEY')||'',service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  const userDb=createClient(url,anon,{global:{headers:{Authorization:token}}});
  const db=createClient(url,service);
  const body=await req.json().catch(()=>({}));
  const placeId=String(body.place_id||'');
  const activity=String(body.activity||'');
  if(!/^[0-9a-f-]{36}$/i.test(placeId) || !selectors[activity])return json({error:'장소 또는 활동이 올바르지 않습니다.'},400);
  const {data:place,error:placeError}=await userDb.from('places').select('id,name,latitude,longitude,address').eq('id',placeId).maybeSingle();
  if(placeError || !place)return json({error:'조회할 수 없는 장소입니다.'},403);
  const {data:cache}=await db.from('place_activity_insights').select('*').eq('place_id',placeId).eq('activity',activity).maybeSingle();
  const force=body.force_refresh===true;
  // A normal reload actually means free-source refresh, not re-reading cache.
  // Throttle requests to protect upstream map providers without charging AI.
  const refreshSources=body.refresh_sources===true;
  const cacheAge=cache?Date.now()-new Date(cache.fetched_at||0).getTime():Infinity;
  if(refreshSources && cache && Array.isArray(cache.spots) && cache.spots.length>0 && Number.isFinite(cacheAge) && cacheAge<10*60000 && !force){
   return json({...cache,cached:true,refresh_throttled:true,
     retry_after_seconds:Math.max(0,Math.ceil((10*60000-cacheAge)/1000))});
  }
  let verifiedReportId:string|null=null;
  let adminId:string|null=null;
  if(force){
   const {data:isAdmin,error:roleError}=await userDb.rpc('is_admin');
   if(roleError||isAdmin!==true)return json({error:'관리자 재검색 권한이 없습니다.'},403);
   adminId=(await userDb.auth.getUser()).data.user?.id||null;
   const reportId=String(body.report_id||'');
   if(!/^[0-9a-f-]{36}$/i.test(reportId))return json({error:'사용자 신고가 있어야 재검색할 수 있습니다.'},403);
   const {data:report,error:reportError}=await db.from('place_activity_reports')
    .select('id').eq('id',reportId).eq('place_id',placeId)
    .eq('activity',activity).eq('status','pending').maybeSingle();
   if(reportError||!report)return json({error:'이 장소와 활동에 대한 미처리 신고가 없습니다.'},403);
   verifiedReportId=reportId;
   // No OpenAI API key is needed for manual free-source refresh.
  }
  // Fast database-only research: check verified national POIs even when there
  // is no research cache. Never hold the first tap open for external providers
  // when a nearby verified location is already stored.
  if(!cache && body.cache_only===true){
    return json({cache_miss:true,cached:false,search_incomplete:true});
  }
  if(!force && !refreshSources && (!cache || !Array.isArray(cache.spots) || cache.spots.length===0)){
    try{
      const verified=await curatedPoi(db,Number(place.latitude),Number(place.longitude),activity);
      if(verified.length>0){
        const now=new Date().toISOString();
        const update={
          summary:place.name+' 주변 반경 3km 안에서 위치·출처가 등록된 '+activity+
             ' 장소 '+verified.length+'곳을 확인했습니다. 이용 허가 및 운영 여부는 현장 확인이 필요합니다.',
          spots:verified,providers:[],photos:[],tips:[
            '출처가 확인된 장소 위치와 실제 이용·입장·채취 허가는 다를 수 있습니다.',
            '운영시간, 계절 및 출입 통제 여부는 현장이나 공식 출처로 확인하세요.'
          ],
          sources:verified.filter(p=>Boolean(validHttp(p.source_url))).map(p=>({name:p.name,url:p.source_url})),
          fetched_at:now,photo_checked_at:now,search_version:SEARCH_VERSION,
          research_status:'verified',ai_generated:false
        };
        const {error}=await db.from('place_activity_insights').upsert(
          {place_id:placeId,activity,radius_m:RANGE,...update},
          {onConflict:'place_id,activity'});
        if(error)console.warn('fast-verified-lookup-write:',error.message);
        return json({...cache,...update,cached:true,verified_poi_fast_path:true});
      }
    }catch(error){
      console.warn('fast-verified-lookup:',String(error).slice(0,130));
    }
  }
  // Cache-first: on a normal revisit NEVER perform tourism, map, blog, photo or
  // AI searches. Every previously researched result is returned immediately.
  // External discovery runs only for uncached places or explicit Refresh.
  if(cache && !force && !refreshSources){
   const saved=Array.isArray(cache.spots)?cache.spots:[];
   return json({...cache,cached:true,search_incomplete:saved.length===0,
    refresh_available:true});
  }
  // The app can synchronize an on-device result without kicking off a search.
  if(body.cache_only===true){
   return json({cache_miss:true,cached:false,search_incomplete:true});
  }
  const lat=Number(place.latitude),lon=Number(place.longitude);
  // A national tourist listing, reviewed POIs and locally contextual map search
  // complement each other. Never depend on a single generic keyword.
  const checks=await Promise.allSettled([
   curatedPoi(db,lat,lon,activity),
   tourApiSearch(lat,lon,activity),
   kakaoSearch(lat,lon,activity,Deno.env.get('KAKAO_REST_API_KEY'),place.name,place.address||'')
  ]);
  let collected:AnyObj[]=[];
  const errors:string[]=[];
  for(let i=0;i<checks.length;i++){
   if(checks[i].status==='fulfilled')collected.push(...(checks[i] as PromiseFulfilledResult<AnyObj[]>).value);
   else errors.push(['Reviewed POIs','KTO','Regional map'][i]+' unavailable');
  }
  let lookupSucceeded=checks.some(x=>x.status==='fulfilled' && x.value.length>0);
  if(collected.length<8){
   try{
    const elements=await overpass(lat,lon,selectors[activity]);
    lookupSucceeded=true;
    for(const e of elements){
     const spot=spotFromElement(e,lat,lon,activity);
     if(spot)collected.push(spot);
    }
   }catch(e){errors.push('OpenStreetMap unavailable');}
  }
  // Nominatim is a backup when API keys/Overpass have no matching places.
  if(collected.length===0){
   try{
    const nearby=await nominatimSearch(lat,lon,activity,place.name);
    if(nearby.length){collected.push(...nearby);lookupSucceeded=true;}
   }catch(e){errors.push('위치 검색 지연');}
  }
  let spots=dedupeSpots(collected,lat,lon,activity);
  let researched:AnyObj|null=null;
  let extraSources:AnyObj[]=[];
  let firstClaimed=false;
  if(spots.length===0){
   if(!force){
    const {data:claimed,error:claimError}=await db.rpc('claim_activity_initial_research',
      {p_place_id:placeId,p_activity:activity});
    if(claimError)return json({error:'최초 검색 상태 확인 오류'},503);
    // A previous initial attempt blocks only paid AI, not free map searching.
    if(claimed===true)firstClaimed=true;
   }
   researched=null; // Paid OpenAI search is disabled in all nearby searches.
   if(researched){
    extraSources=researched.sources||[];
    for(const candidate of researched.candidates||[]){
     const verified=await verifyCandidate(place,activity,candidate);
     if(verified && !spots.some(x=>x.name===verified.name))spots.push(verified);
     if(spots.length>=3)break;
     await new Promise(resolve=>setTimeout(resolve,1100));
    }
    spots.sort((a,b)=>a.distance_m-b.distance_m);
   }
  }

  if(spots.length===0 && cache && Array.isArray(cache.spots) && cache.spots.length>0){
   return json({...cache,cached:true,stale:true,search_incomplete:true,
     summary:'현재 검색 제공자가 새로운 장소를 확인하지 못해 이전 확인 자료를 보존합니다.'});
  }
  if(spots.length===0){
   let naverRelated:AnyObj[]=[];
   if(activity==='해루질'||activity==='낚시'){
    const research=await Promise.allSettled([
     naverBlogEvidence(place.name,activity),
     youtubeFishingEvidence(place.name,activity)
    ]);
    if(research[0].status==='fulfilled')naverRelated.push(...research[0].value);
    else errors.push('Naver blog search unavailable');
    if(research[1].status==='fulfilled')naverRelated.push(...research[1].value);
    else if(activity==='낚시')errors.push('YouTube search unavailable');
    naverRelated=[...new Map(naverRelated.map(d=>[d.source_url,d])).values()].slice(0,8);
   }
   const anchor=activity==='낚시'?fishingPortAnchor(place,naverRelated,lat,lon):null;
   if(anchor && !force){
    const now=new Date().toISOString();
    const update={spots:[anchor],
     summary:'항구 주변 낚시 관련 문서를 확인했지만 실제 낚시가 허용된 상세 구역은 아직 검증되지 않았습니다. 핀은 항구 대표 위치입니다.',
     suggested_places:naverRelated,
     sources:[{name:anchor.name,url:anchor.source_url}],
     research_status:'candidate',ai_generated:false,
     search_version:SEARCH_VERSION,fetched_at:now
    };
    const {error}=await db.from('place_activity_insights').upsert({
     place_id:placeId,activity,radius_m:RANGE,...update
    },{onConflict:'place_id,activity'});
    if(error)console.warn('fishing-anchor-cache:',error.message);
    return json({...cache,...update,cached:true,source_candidate:true});
   }
   // Source-backed candidates are distinct from verified places inside 3km.
   const suggested=[...naverRelated,...(researched?.candidates||[]).map((p:AnyObj)=>({
    name:String(p.name||'').slice(0,100),source_url:validHttp(p.source_url),
    location_verified:false,
    note:'공개 웹자료에서 찾은 후보입니다. 3km 이내 위치는 확인되지 않았습니다.'
   }))].slice(0,6);
   const summary=(researched || naverRelated.length>0)
    ? (suggested.length>0
       ? '주변 관련 정보를 재검색해 '+suggested.map((p:AnyObj)=>p.name).join(' · ')+
         ' 등의 자료를 찾았습니다. 다만 위치 데이터가 확인되지 않아 반경 3km 확정 목록에는 포함하지 않았습니다. 출처에서 직접 확인하거나 변경 신고를 남겨주세요.'
       : '공개 관광·지도 자료에서 반경 3km 이내 위치가 확인된 '+activity+' 장소는 아직 찾지 못했습니다. 이용 불가라는 뜻은 아닙니다.')
    : '일부 공개 관광·지도 제공자 검색이 원활하지 않습니다. 검색 실패는 주변 정보가 없다는 뜻이 아닙니다.';
   if(force)return json({error:'공개 지도·관광자료에서 위치를 확인하지 못해 이전 기록을 유지했습니다.'},503);
   if(researched || naverRelated.length>0){
    const now=new Date().toISOString();
    const item={place_id:placeId,activity,radius_m:RANGE,summary,
     spots:[],providers:[],photos:[],sources:extraSources,suggested_places:suggested,
     tips:['확인된 자료 없음은 이용 불가를 의미하지 않습니다.','새로운 정보가 있다면 신고해주세요.'],
     fetched_at:now,photo_checked_at:now,expires_at:null,
     research_status:'not_confirmed',ai_generated:false,search_version:SEARCH_VERSION};
    const {error:saveError}=await db.from('place_activity_insights').upsert(item,{
      onConflict:'place_id,activity',ignoreDuplicates:true});
    if(saveError)return json({error:'조사 결과를 저장하지 못했습니다.'},503);
    if(firstClaimed)await db.from('place_activity_first_attempts')
      .update({outcome:'not_confirmed',finished_at:now})
      .eq('place_id',placeId).eq('activity',activity);
    return json({...item,cached:true,checked_once:true,search_incomplete:true});
   }
   if(firstClaimed)await db.from('place_activity_first_attempts')
    .update({outcome:'error',finished_at:new Date().toISOString()})
    .eq('place_id',placeId).eq('activity',activity);
   return json({summary,place_id:placeId,activity,radius_m:RANGE,
    spots:[],providers:[],photos:[],sources:[],
    tips:['서버 오류가 해결되면 관리자 신고·확인 절차를 이용해 주세요.'],
    temporarily_unavailable:true,search_incomplete:true,cached:false,ai_generated:false});
  }
  const providers=spots.filter(s=>s.phone || s.website).slice(0,12);
  const primary=spots.slice(0,3).map(s=>s.name).join('·');
  const fallback=spots.length>0
   ? (place.name+' 주변 3km 이내 공개지도에 '+spots.length+'곳의 '+activity+' 관련 장소가 확인됩니다. 가까운 곳: '+primary+'.')
   : (place.name+' 주변 3km 이내 공개지도에서 '+activity+' 관련 장소를 확인하지 못했습니다. 정보가 없다는 뜻이지 이용이 불가능하다는 뜻은 아닙니다.');
  // Show sourced information directly. No charged OpenAI Responses API calls.
  const caution=(activity==='해루질'||activity==='낚시')
   ? '채취·낚시 가능 구역, 출입 제한, 금어기, 기상 및 물때를 현장에서 반드시 확인하세요. 위치 정보만으로 합법적인 이용이 보장되지 않습니다.'
   : activity==='수상레포츠'
   ? '서핑·수영·스노클링·카약·SUP 정보를 통합해 제공합니다. 해수욕장·강·계곡 물놀이는 후보일 수 있으며 입수·출입 허용 여부, 파도·급류·수심·수질 및 기상을 현장에서 확인하세요.'
   : '운영시간·요금·예약·입장 가능 여부는 출발 전 공식 안내 또는 해당 업체에 확인하세요.';
  const sources=[...spots.map(s=>({name:s.name,url:s.source_url})),...extraSources]
    .filter((s:AnyObj)=>Boolean(validHttp(s.url))).slice(0,26);
  const photos=await photoList(spots);
  const now=new Date().toISOString();
  const record={place_id:place.id,activity,radius_m:RANGE,
   summary:fallback,spots,providers,photos,tips:[caution],sources,
   fetched_at:now,photo_checked_at:now,expires_at:null,
   research_status:'verified',ai_generated:false,search_version:SEARCH_VERSION};
  const {error:writeError}=await db.from('place_activity_insights').upsert(record,{onConflict:'place_id,activity'});
  if(writeError){return json({...record,warning:'캐시 저장 실패: '+writeError.message,cached:false});}
  if(firstClaimed)await db.from('place_activity_first_attempts')
    .update({outcome:'verified',finished_at:new Date().toISOString()})
    .eq('place_id',placeId).eq('activity',activity);
  if(spots.length>0 && activity!=='해루질') {
   await db.from('place_activity_candidates').upsert({place_id:place.id,activity,radius_m:RANGE,spot_count:spots.length,example_spot:spots[0].name,source_url:spots[0].source_url,updated_at:new Date().toISOString()},{onConflict:'place_id,activity',ignoreDuplicates:true});
  }
  if(force&&verifiedReportId){
   const {error:finishError}=await db.from('place_activity_reports')
    .update({status:'resolved',admin_id:adminId,resolved_at:new Date().toISOString()})
    .eq('id',verifiedReportId).eq('status','pending');
   if(finishError)return json({...record,cached:false,warning:'AI 요약 저장됨, 신고 처리상태 갱신 실패'});
  }
  return json({...record,cached:false});
 }catch(e){return json({error:'검색 중 오류가 발생했습니다.',details:String(e).slice(0,150)},500);}
});
