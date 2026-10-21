import { createClient } from "npm:@supabase/supabase-js@2.49.10";

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Content-Type": "application/json; charset=utf-8" };
const RANGE = 3000;
type AnyObj = Record<string, any>;
const selectors: Record<string, string[]> = {
  "관광지": ['["tourism"~"^(attraction|museum|viewpoint|zoo|aquarium|gallery)$"]', '["historic"]'],
  "산책": ['["leisure"~"^(park|garden|nature_reserve)$"]','["highway"~"^(path|footway|pedestrian|steps)$"]["name"]','["route"="foot"]','["tourism"="viewpoint"]'],
  "등산": ['["route"="hiking"]', '["natural"="peak"]', '["information"="guidepost"]'],
  "낚시": ['["sport"="fishing"]','["fishing"]','["leisure"="fishing"]',
   '["man_made"~"^(breakwater|pier)$"]["name"]','["harbour"]["name"]',
   '["seamark:type"="harbour"]["name"]','["man_made"="quay"]["name"]'],
  "해루질": ['["natural"~"^(beach|mud)$"]','["wetland"="tidalflat"]',
   '["natural"="wetland"]["wetland"~"^(tidalflat|saltmarsh)$"]',
   '["tourism"="attraction"]["name"~"갯벌|해루질|조개잡이|어촌체험"]'],
  "수상레포츠": ['["sport"~"^(sailing|surfing|canoe|kayaking|kitesurfing|scuba_diving|windsurfing)$"]', '["leisure"="marina"]'],
  "지상레포츠": ['["sport"~"^(climbing|paragliding|archery|motocross|skateboard|horse_racing)$"]','["leisure"="sports_centre"]'],
  "카지노": ['["amenity"="casino"]'],
  "자전거": ['["route"="bicycle"]','["shop"="bicycle"]','["highway"="cycleway"]["name"]'],
  // Waterways are water-play candidates, NOT proof that entry is allowed.
  "수영": ['["leisure"="swimming_pool"]','["sport"="swimming"]',
   '["leisure"~"^(water_park|swimming_area|bathing_place)$"]',
   '["natural"="beach"]["name"]',
   '["waterway"~"^(river|stream)$"]["name"~"물놀이|계곡|수영"]',
   '["tourism"="attraction"]["name"~"물놀이|계곡"]'],
  "서핑": ['["sport"="surfing"]','["shop"="surf"]'],
  "카약·SUP": ['["sport"~"^(canoe|kayaking|stand_up_paddle)$"]','["canoe"]'],
  "스노클링": ['["sport"~"^(scuba_diving|snorkeling)$"]'],
  "스키·눈썰매": ['["piste:type"]','["sport"="skiing"]'],
  "골프": ['["leisure"="golf_course"]','["sport"="golf"]'],
  "온천·스파": ['["amenity"="public_bath"]','["leisure"="spa"]','["natural"="hot_spring"]'],
  "문화체험": ['["tourism"~"^(museum|gallery)$"]','["amenity"~"^(arts_centre|theatre|community_centre)$"]'],
  // Seafood retail and boat markets are part of market/shopping.
  "시장·쇼핑": ['["amenity"="marketplace"]',
   '["shop"~"^(fishmonger|seafood|supermarket|general|convenience|mall|department_store)$"]',
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
 if(t["natural"]==="peak")return "산·봉우리";
 if(t["amenity"]==="casino")return "카지노";
 if(t["leisure"]==="marina")return "마리나";
 if(activity==="수영" && (t["waterway"]||t["natural"]==="beach"||t["tourism"]==="attraction"))
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
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),8500);
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
 if(!name)return null;
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
 // A tourist port can also be an evidence-backed fishing location.
 if(matches.length===0){
  const {data:related,error:relatedError}=await db.from('verified_activity_pois').select('*')
   .contains('related_activities',[activity])
   .gte('latitude',lat-latDelta).lte('latitude',lat+latDelta)
   .gte('longitude',lon-lonDelta).lte('longitude',lon+lonDelta).limit(75);
  if(relatedError)console.warn('related activity:',String(relatedError.message).slice(0,80));
  else matches=(related||[]) as AnyObj[];
 }
 return matches.map((p:AnyObj)=>normalizePlace({
  name:p.name,lat:p.latitude,lon:p.longitude,kind:activity,
  description:p.description,phone:p.phone,website:p.info_source_url,
  source_url:p.info_source_url||p.map_source_url,
 },lat,lon,activity)).filter(Boolean) as AnyObj[];
}
// Search the names people actually use, not just abstract category labels.
const searchTerms:Record<string,string[]>={
 '관광지':['관광명소','전망대','관광지'],
 '산책':['산책로','수변공원','둘레길','해안길','벽화골목'],
 '등산':['등산로','등산','둘레길'],
 '낚시':['낚시포인트','선착장','방파제','낚시터','항구','포구','워킹낚시'],
 '해루질':['해루질','갯벌체험','갯벌','어촌체험','조개잡이','바지락체험'],
 '수상레포츠':['수상레저','서핑','카약','SUP'],
 '지상레포츠':['스카이사이클','짚라인','스카이밸리','ATV','레포츠'],
 '카지노':['카지노'], '자전거':['자전거체험','스카이사이클','자전거길'],
 '수영':['계곡 물놀이','강/물놀이','물놀이장','수영장','해수욕장','계곡'], '서핑':['서핑','서핑샵'],
 '카약·SUP':['카약','SUP'], '스노클링':['스노클링','다이빙'],
 '스키·눈썰매':['스키장','눈썰매'], '골프':['골프장','파크골프'],
 '온천·스파':['온천','스파','목욕탕'],
 '문화체험':['문화체험','박물관','문화마을'],
 '시장·쇼핑':['수산물직매장','선상어시장','선상횟집','수산물센터','어시장','수산시장','어판장','전통시장','마트','시장']
};
const discoveryKeywords:Record<string,string>=Object.fromEntries(
 Object.entries(searchTerms).map(([key,terms])=>[key,terms[0]]));
async function kakaoSearch(lat:number,lon:number,activity:string,key:string|undefined,placeName=''){
 if(!key)return [] as AnyObj[];
 const root=placeName.replace(/(공영주차장|주차장|노지|차박|캠핑장|야영장|주변)/g,'').trim().slice(0,30);
 const targeted=root && activity==='시장·쇼핑'
  ? [root+' 수산물직매장',root+' 선상어시장',root+' 어시장',root+' 시장']
  : root && (activity==='낚시'||activity==='해루질')
  ? [root+' '+activity,root+' 선착장'] : [];
 const count=activity==='시장·쇼핑'?9:activity==='낚시'?7:activity==='수영'||activity==='해루질'?6:4;
 const terms=[...new Set([...targeted,...(searchTerms[activity]||[activity])])].slice(0,count);
 const found:AnyObj[]=[];
 for(const term of terms){
  const url='https://dapi.kakao.com/v2/local/search/keyword.json?'+
    new URLSearchParams({query:term,x:String(lon),y:String(lat),radius:String(RANGE),size:'15',sort:'distance'});
  const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),activity==='시장·쇼핑'?2800:3500);
  try{
   const r=await fetch(url,{headers:{Authorization:'KakaoAK '+key},signal:ctrl.signal});
   if(!r.ok)continue;
   const data=await r.json();
   for(const d of data.documents||[]){
    if(activity==='시장·쇼핑' &&
       !/수산|어시장|시장|직매장|어판장|선상|회뜨는|마트|쇼핑|상설|장터|활어|회센터|회센타/i.test(
        String(d.place_name||'')+' '+String(d.category_name||'')))continue;
    const kind=activity==='낚시'&&/방파제|선착장|항구/.test(term)
      ? '낚시 관련 해안시설 후보 (출입·낚시 허용 여부 현장 확인)'
      : activity;
    const waterCandidate=activity==='수영' && /계곡|강변|하천|유원지|물놀이/i.test(String(d.place_name||''));
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
  }catch(e){console.warn('Kakao keyword lookup:',String(e).slice(0,80));}
  finally{clearTimeout(timer);}
  if(found.length>=15 && activity!=='시장·쇼핑')break;
 }
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
 if(!name || !Number.isFinite(la) || !Number.isFinite(lo))return null;
 const meters=Math.round(distanceM(lat,lon,la,lo));
 if(meters>RANGE)return null;
 const url='https://www.openstreetmap.org/'+e.type+'/'+e.id;
 const phone=String(t['contact:phone']||t.phone||'').trim().slice(0,90);
 const website=String(t['contact:website']||t.website||'').trim();
 const safeWebsite=/^https?:\/\//i.test(website)?website:'';
 return {name,lat:la,lon:lo,distance_m:meters,kind:label(t,activity),address:String(t['addr:full']||t['addr:street']||'').slice(0,160),phone,website:safeWebsite,opening_hours:String(t.opening_hours||'').slice(0,120),fee:String(t.fee||'').slice(0,45),description:String(t['description:ko']||t.description||(
  activity==='수영' && (t.waterway||t.natural==='beach'||t.tourism==='attraction')
   ? '강·계곡·하천 물놀이 관련 지형 후보입니다. 수영 허용 여부, 급류·수심·수질·기상 상황을 현장에서 확인하세요.'
   : ''
 )).slice(0,250),source_url:url,photo_hint:String(t.wikimedia_commons||'').startsWith('File:')?String(t.wikimedia_commons):''};
}
// AI searches fresh public web sources only when a server-side API key is configured.
// It may enrich descriptions of independently geolocated POIs, but must not create
// map points or phone numbers from its own unverified text.
async function onlineAISummary(
 name:string, activity:string, spots:AnyObj[], key:string|undefined, db:any,
 ctx:{placeId:string,reportId:string|null,adminId:string|null}
):Promise<{summary:string,sources:AnyObj[]}|null>{
 if(!key || spots.length===0)return null;
 const requestId=crypto.randomUUID();
 const reserve=await db.rpc('reserve_camping_ai_budget',{
  p_request_id:requestId,p_place_id:ctx.placeId,p_activity:activity,
  p_report_id:ctx.reportId,p_admin_id:ctx.adminId
 });
 if(reserve.error)throw new Error('AI 예산 검증 오류');
 if(reserve.data!==true)throw new Error('AI 월간 예산 30,000원에 도달했거나 남은 예산이 부족합니다.');
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),17000);
 let settled=false;
 const settle=async(ok:boolean,krw:number,inputs:number,outputs:number,calls:number,responseId:string,errorCode:string)=>{
  try{
   const {error}=await db.rpc('settle_camping_ai_budget',{
    p_request_id:requestId,p_completed:ok,p_actual_krw:krw,
    p_input_tokens:inputs,p_output_tokens:outputs,p_web_search_calls:calls,
    p_response_id:responseId,p_error_code:errorCode
   });
   if(error)console.error('AI usage settlement failed:',error.message);
   else settled=true;
  }catch(e){console.error('AI usage settlement transport error:',String(e));}
 };
 try{
  const nearby=spots.slice(0,8).map(s=>({name:s.name,kind:s.kind,distance_m:s.distance_m,
   website:s.website,source_url:s.source_url}));
  const prompt=[
   '한국 캠핑카 여행 정보 사이트의 최신 주변 활동 요약을 작성하세요.',
   '장소: '+name,'활동: '+activity,'허용 검색반경: 중심 기준 직선거리 3km.',
   '제공된 좌표 확인 장소만 설명하며 새로운 장소, 업체, 전화번호, 낚시 포인트를 만들지 마세요.',
   '공식출처 없는 운영시간·가격·출항여부·합법적 해루질 허가를 추정하지 마세요.',
   '웹에서 최신 출처를 확인하고 2~4문장 한국어로 정리하세요.',
   '좌표 확인 장소: '+JSON.stringify(nearby)
  ].join('\\n');
  const response=await fetch('https://api.openai.com/v1/responses',{
   method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+key},
   body:JSON.stringify({model:'gpt-4.1-mini',tools:[{type:'web_search',search_context_size:'low'}],
    tool_choice:'required',max_output_tokens:350,input:prompt}),signal:controller.signal
  });
  if(!response.ok){
   await settle(false,0,0,0,0,'','openai_http_'+response.status);
   console.warn('OpenAI HTTP '+response.status);
   return null;
  }
  const body=await response.json();
  const contents=(body.output||[]).flatMap((x:AnyObj)=>Array.isArray(x.content)?x.content:[])
   .filter((x:AnyObj)=>x.type==='output_text');
  const summary=contents.map((x:AnyObj)=>String(x.text||'')).join(' ').trim().slice(0,900);
  const citations=new Map<string,AnyObj>();
  for(const item of contents)for(const c of item.annotations||[]){
   if(c.type!=='url_citation')continue;
   const url=validHttp(c.url);
   if(url&&!citations.has(url))citations.set(url,{name:String(c.title||'웹 검색 출처').slice(0,90),url});
  }
  const inputTokens=Math.max(0,Number(body.usage?.input_tokens||0));
  const outputTokens=Math.max(0,Number(body.usage?.output_tokens||0));
  const calls=Math.max(1,(body.output||[]).filter((v:AnyObj)=>v.type==='web_search_call').length);
  // OpenAI search tool is $10/1k calls and GPT-4.1 mini is $0.40/$1.60 per 1M
  // input/output tokens. Add the 8k-token search-content block conservatively.
  // This is an estimate, not a guarantee of the external OpenAI invoice total.
  const estimatedUsd=calls*.01+(inputTokens+8000*calls)*.40/1000000+outputTokens*1.60/1000000;
  const estimatedKrw=Math.max(1,Math.ceil(estimatedUsd*1500));
  await settle(true,estimatedKrw,inputTokens,outputTokens,calls,String(body.id||''),'');
  if(!settled)throw new Error('AI 사용량 기록에 실패했습니다.');
  if(!summary||citations.size===0)return null;
  return {summary,sources:[...citations.values()].slice(0,8)};
 }catch(e){
  if(!settled)await settle(false,0,0,0,0,'',String(e).slice(0,100));
  if(String(e).includes('AI 사용량'))throw e;
  console.warn('AI web search unavailable:',String(e).slice(0,150));
  return null;
 }finally{clearTimeout(timer);}
}


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
async function aiFallback(db:any,place:AnyObj,activity:string):Promise<{summary:string,sources:AnyObj[],candidates:AnyObj[]}|null>{
 const key=Deno.env.get('OPENAI_API_KEY');
 if(!key)return null;
 const id=crypto.randomUUID();
 const hold=await db.rpc('reserve_camping_ai_budget',{
  p_request_id:id,p_place_id:place.id,p_activity:activity,p_report_id:null,p_admin_id:null});
 if(hold.error || hold.data!==true)return null;
 let settled=false;
 const settle=async(ok:boolean,cost:number,inputs:number,outputs:number,calls:number,responseId:string,err:string)=>{
  const {error}=await db.rpc('settle_camping_ai_budget',{
   p_request_id:id,p_completed:ok,p_actual_krw:cost,p_input_tokens:inputs,
   p_output_tokens:outputs,p_web_search_calls:calls,p_response_id:responseId,p_error_code:err});
  settled=!error;
 };
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),17000);
 try{
  const input=[
   '대한민국 캠핑카 여행 장소의 3km 이내 활동을 다양한 공개 웹정보로 조사하세요.',
   '장소: '+place.name+' 위도 '+place.latitude+' 경도 '+place.longitude,
   '활동: '+activity+' / 구체 검색어: '+(searchTerms[activity]||[activity]).join(', '),
   '한 가지 추상 분류어만 검색하지 마세요. 지자체 관광, 한국관광공사, 국내 지역 블로그·낚시 조황 및 지도 안내 등 서로 다른 출처로 교차 검증하세요.',
   '산책은 벽화골목·해안길·수변공원, 낚시는 내항·방파제·선착장, 지상레포츠는 와이어 자전거·스카이사이클·짚라인까지 조사하세요.',
   '장소 이름과 출처를 최대 5곳 반환하고, 근거 없이 장소·좌표·연락처·어종을 지어내지 마세요. 일부 검색사이트는 접근이 제한될 수 있습니다.',
   '낚시 가능 구간은 출입금지·위험 테트라포드와 구분하고, 실제 어획은 보장하지 마세요.',
    'JSON 객체 형식으로만 응답하세요. summary는 검색 근거 요약, places는 확인된 실제 장소 고유명칭과 열리는 출처 URL 배열입니다. 안내 예시 텍스트를 장소명 또는 URL로 복사하지 마세요.',
   '후보의 좌표·3km 이내 여부는 다른 지도 제공자가 최종 확인합니다.'
  ].join('\\n');
  const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',
   headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},
   body:JSON.stringify({model:'gpt-4.1-mini',tools:[{type:'web_search',search_context_size:'low'}],
    tool_choice:'required',max_output_tokens:850,input}),signal:ctrl.signal});
  if(!r.ok){await settle(false,0,0,0,0,'','http_'+r.status);return null;}
  const body=await r.json();
  const texts=(body.output||[]).flatMap((x:AnyObj)=>x.content||[]).filter((x:AnyObj)=>x.type==='output_text');
  const raw=texts.map((x:AnyObj)=>String(x.text||'')).join('');
  const sources=new Map<string,AnyObj>();
  for(const x of texts)for(const c of x.annotations||[]){
   if(c.type==='url_citation' && validHttp(c.url))sources.set(c.url,{name:String(c.title||'AI 검색 출처'),url:c.url});
  }
  const inputs=Math.max(0,Number(body.usage?.input_tokens||0));
  const outputs=Math.max(0,Number(body.usage?.output_tokens||0));
  const calls=Math.max(1,(body.output||[]).filter((x:AnyObj)=>x.type==='web_search_call').length);
  const estimate=Math.ceil((calls*.01+(inputs+8000*calls)*.4/1000000+outputs*1.6/1000000)*1500);
  await settle(true,estimate,inputs,outputs,calls,String(body.id||''),'');
  if(!settled)return null;
  let parsed:AnyObj={};
  try{parsed=JSON.parse(raw.slice(raw.indexOf('{'),raw.lastIndexOf('}')+1));}
  catch(_){return {summary:'',sources:[...sources.values()],candidates:[]};}
  const candidates=(Array.isArray(parsed.places)?parsed.places:[]).slice(0,5)
   .map((p:AnyObj)=>({name:String(p.name||'').slice(0,90),source_url:validHttp(p.source_url)}))
   .filter((p:AnyObj)=>{
    const label=p.name.trim().toLowerCase();
    if(label.length<3 || /실제.?시설명|고유명칭|예시|장소명|시설명|^낚시포인트$|^주변장소$|^test$/i.test(label))return false;
    try{
     const url=new URL(p.source_url);
     return (url.protocol==='https:'||url.protocol==='http:') &&
      url.hostname.includes('.') && !/원문|예시|example|localhost|\.invalid/i.test(p.source_url);
    }catch(_){return false;}
   });
  return {summary:String(parsed.summary||'').slice(0,500),sources:[...sources.values()],candidates};
 }catch(e){console.warn('AI discovery unavailable:',String(e).slice(0,90));if(!settled)await settle(false,0,0,0,0,'','request_error');return null;}
 finally{clearTimeout(timer);}
}
// Match meaningful place-name tokens, not only exact map label text.
// "도째비골 스카이사이클" and "도째비골 스카이밸리" can reference
// the same venue even when their full strings differ.
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
  const {data:place,error:placeError}=await userDb.from('places').select('id,name,latitude,longitude').eq('id',placeId).maybeSingle();
  if(placeError || !place)return json({error:'조회할 수 없는 장소입니다.'},403);
  const {data:cache}=await db.from('place_activity_insights').select('*').eq('place_id',placeId).eq('activity',activity).maybeSingle();
  const force=body.force_refresh===true;
  let verifiedReportId:string|null=null;
  let adminId:string|null=null;
  if(force){
   const {data:isAdmin,error:roleError}=await userDb.rpc('is_admin');
   if(roleError||isAdmin!==true)return json({error:'AI 재검색은 관리자만 실행할 수 있습니다.'},403);
   adminId=(await userDb.auth.getUser()).data.user?.id||null;
   const reportId=String(body.report_id||'');
   if(!/^[0-9a-f-]{36}$/i.test(reportId))return json({error:'사용자 신고가 있어야 재검색할 수 있습니다.'},403);
   const {data:report,error:reportError}=await db.from('place_activity_reports')
    .select('id').eq('id',reportId).eq('place_id',placeId)
    .eq('activity',activity).eq('status','pending').maybeSingle();
   if(reportError||!report)return json({error:'이 장소와 활동에 대한 미처리 신고가 없습니다.'},403);
   verifiedReportId=reportId;
   if(!Deno.env.get('OPENAI_API_KEY'))return json({error:'OpenAI API 키가 등록되지 않아 AI 재검색을 실행할 수 없습니다.'},503);
  }
  // A negative cache must reflect newly verified POIs without extra paid AI searches.
  if(cache && !force){
   const cachedSpots=Array.isArray(cache.spots)?cache.spots:[];
   if(cachedSpots.length===0){
    try{
     const fresh=await curatedPoi(db,Number(place.latitude),Number(place.longitude),activity);
     if(fresh.length>0){
      const now=new Date().toISOString();
      const names=fresh.slice(0,3).map(s=>s.name).join(' · ');
      const summary=place.name+' 주변 3km 이내 공개자료에서 '+activity+
       ' 관련 장소 '+fresh.length+'곳을 확인했습니다: '+names+
       '. 활동 관련 장소 위치가 확인됐으나 실제 출입·채취 허가와 안전은 현장에서 별도 확인하세요.';
      const sources=fresh.filter(s=>Boolean(validHttp(s.source_url)))
       .map(s=>({name:s.name,url:s.source_url}));
      const tips=activity==='해루질'
       ? ['해루질 관련 위치는 현재 채취·출입 허가를 뜻하지 않습니다. 어촌계·마을어장 규정을 확인하세요.',
          '갯골·물때·기상과 안전장비를 확인하세요.']
       : activity==='수영'?
       ['물놀이 관련 장소 후보는 수영 허가·안전 확인을 의미하지 않습니다.',
        '상수원 보호, 출입 통제, 수심·급류·기상·수질을 현장에서 확인하세요.']:
       ['정보 출처와 출입·운영 조건은 이용 전 확인하세요.'];
      const patch={summary,spots:fresh,providers:[],sources,tips,
       research_status:'verified',fetched_at:now,ai_generated:false,search_version:5};
      const {error}=await db.from('place_activity_insights')
       .update(patch).eq('place_id',placeId).eq('activity',activity);
      if(!error)return json({...cache,...patch,cached:true,curated_refreshed:true});
      console.warn('curated-cache-write:',error.message);
     }
    }catch(e){console.warn('curated-cache-lookup:',String(e).slice(0,100));}
   }
   // Old empty caches get one free revised map search (then every 30 days).
   // This must never run the paid AI model.
   if(cachedSpots.length===0){
    const age=Date.now()-new Date(cache.fetched_at||0).getTime();
    if(Number(cache.search_version||0)<5 || !Number.isFinite(age) || age>30*86400000){
     const lat=Number(place.latitude),lon=Number(place.longitude),items:AnyObj[]=[];
     try{items.push(...await kakaoSearch(lat,lon,activity,Deno.env.get('KAKAO_REST_API_KEY'),place.name));}
     catch(e){console.warn('cached-local-search:',String(e).slice(0,80));}
     if(items.length===0){
      try{for(const element of await overpass(lat,lon,selectors[activity])){
       const match=spotFromElement(element,lat,lon,activity);
       if(match)items.push(match);
      }}catch(e){console.warn('cached-osm-search:',String(e).slice(0,80));}
     }
     if(items.length===0){
      try{items.push(...await nominatimSearch(lat,lon,activity,place.name));}
      catch(e){console.warn('cached-name-search:',String(e).slice(0,80));}
     }
     const unique=new Map<string,AnyObj>();
     for(const candidate of items){
      const p=normalizePlace(candidate,lat,lon,activity);
      if(p)unique.set(p.name.toLowerCase()+'-'+Math.round(p.lat*1000)+'-'+Math.round(p.lon*1000),p);
     }
     const found=[...unique.values()].sort((a,b)=>a.distance_m-b.distance_m).slice(0,20);
     const now=new Date().toISOString();
     if(found.length>0){
      const summary=place.name+' 주변 3km 이내 '+activity+' 관련 장소 '+found.length+
       '곳이 공개 지도에서 검색됐습니다. 위치만으로 실제 활동·출입·채취 허가가 확인된 것은 아닙니다.';
      const sources=found.filter(p=>Boolean(validHttp(p.source_url)))
       .map(p=>({name:p.name,url:p.source_url}));
      const tips=activity==='해루질'
       ? ['해루질 후보 위치는 현재 채취·출입 허가를 뜻하지 않습니다. 어촌계·마을어장 규정과 금어기를 확인하세요.',
          '갯골·물때·기상과 안전장비를 확인하세요.']
       : activity==='수영'
       ? ['강·계곡의 수영·물놀이는 출입 허용, 수심·급류·수질·기상 확인이 필요합니다.']
       : ['현장 운영·출입 조건을 확인하세요.'];
      const update={spots:found,summary,sources,tips,providers:found.filter(p=>p.phone||p.website),
       research_status:'verified',ai_generated:false,fetched_at:now,search_version:5};
      const {error}=await db.from('place_activity_insights')
       .update(update).eq('place_id',placeId).eq('activity',activity);
      if(!error)return json({...cache,...update,cached:true,free_map_refreshed:true});
      console.warn('cached-refresh-save:',error.message);
     }else{
      await db.from('place_activity_insights')
       .update({search_version:5,fetched_at:now})
       .eq('place_id',placeId).eq('activity',activity);
     }
    }
   }
   // One-time licensed-photo enrichment, never a paid AI re-search.
   if(!cache.photo_checked_at){
    const images=await photoList(Array.isArray(cache.spots)?cache.spots:[]);
    const now=new Date().toISOString();
    const {error}=await db.from('place_activity_insights')
     .update({photos:images,photo_checked_at:now})
     .eq('place_id',placeId).eq('activity',activity).is('photo_checked_at',null);
    if(!error)return json({...cache,photos:images,photo_checked_at:now,cached:true});
   }
   return json({...cache,cached:true,ai_generated:Boolean(cache.ai_generated)});
  }
  const lat=Number(place.latitude),lon=Number(place.longitude);
  // Search our existing verified dataset first, even on the very first tap.
  let collected:AnyObj[]=[];
  try{collected=await curatedPoi(db,lat,lon,activity);}catch(e){console.warn('curated POI lookup:',String(e));}
  const errors:string[]=[];
  let lookupSucceeded=collected.length>0;
  // Fresh results are persisted so subsequent opens do not repeat internet searches.
  try{
   const kakao=await kakaoSearch(lat,lon,activity,Deno.env.get('KAKAO_REST_API_KEY'),place.name);
   if(kakao.length) {collected.push(...kakao);lookupSucceeded=true;}
  }catch(e){errors.push('지역검색 연결 문제');}
  if(collected.length===0 || body.force_refresh===true ||
    ((activity==='수영'||activity==='낚시'||activity==='해루질'||activity==='시장·쇼핑') && collected.length<5)){
   try{
    const elements=await overpass(lat,lon,selectors[activity]);
    lookupSucceeded=true;
    for(const e of elements){
     const raw=spotFromElement(e,lat,lon,activity);
     if(raw)collected.push(raw);
    }
   }catch(e){errors.push('공개지도 검색 지연');}
  }
  // Nominatim is a backup when API keys/Overpass have no matching places.
  if(collected.length===0){
   try{
    const nearby=await nominatimSearch(lat,lon,activity,place.name);
    if(nearby.length){collected.push(...nearby);lookupSucceeded=true;}
   }catch(e){errors.push('위치 검색 지연');}
  }
  const unique=new Map<string,AnyObj>();
  for(const candidate of collected){
   const item=normalizePlace(candidate,lat,lon,activity);
   if(!item)continue;
   const id=(item.name.trim().toLocaleLowerCase()+'-'+Math.round(item.lat*1000)+'-'+Math.round(item.lon*1000));
   if(!unique.has(id))unique.set(id,item);
  }
  let spots=[...unique.values()].sort((a,b)=>a.distance_m-b.distance_m).slice(0,20);
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
   researched=firstClaimed ? await aiFallback(db,place,activity) : null;
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

  if(spots.length===0){
   // Source-backed candidates are distinct from verified places inside 3km.
   const suggested=(researched?.candidates||[]).map((p:AnyObj)=>({
    name:String(p.name||'').slice(0,100),source_url:validHttp(p.source_url),
    location_verified:false,
    note:'공개 웹자료에서 찾은 후보입니다. 3km 이내 위치는 확인되지 않았습니다.'
   })).slice(0,5);
   const summary=researched
    ? (suggested.length>0
       ? '주변 관련 정보를 재검색해 '+suggested.map((p:AnyObj)=>p.name).join(' · ')+
         ' 등의 자료를 찾았습니다. 다만 위치 데이터가 확인되지 않아 반경 3km 확정 목록에는 포함하지 않았습니다. 출처에서 직접 확인하거나 변경 신고를 남겨주세요.'
       : 'AI 웹검색을 시도했으나 반경 3km 이내에서 위치까지 검증된 '+activity+' 장소는 아직 확인하지 못했습니다. 이용 불가라는 뜻은 아닙니다.')
    : '현재 공개지도·AI 확인이 원활하지 않습니다. 정보가 있다면 신고해주세요.';
   if(force)return json({error:'관리자 AI 재검색에서 확인된 장소가 없어 이전 기록을 유지했습니다.'},503);
   if(researched){
    const now=new Date().toISOString();
    const item={place_id:placeId,activity,radius_m:RANGE,summary,
     spots:[],providers:[],photos:[],sources:extraSources,suggested_places:suggested,
     tips:['확인된 자료 없음은 이용 불가를 의미하지 않습니다.','새로운 정보가 있다면 신고해주세요.'],
     fetched_at:now,photo_checked_at:now,expires_at:null,
     research_status:'not_confirmed',ai_generated:false,search_version:5};
    const {error:saveError}=await db.from('place_activity_insights').upsert(item,{
      onConflict:'place_id,activity',ignoreDuplicates:true});
    if(saveError)return json({error:'조사 결과를 저장하지 못했습니다.'},503);
    if(firstClaimed)await db.from('place_activity_first_attempts')
      .update({outcome:'not_confirmed',finished_at:now})
      .eq('place_id',placeId).eq('activity',activity);
    return json({...item,cached:true,checked_once:true});
   }
   if(firstClaimed)await db.from('place_activity_first_attempts')
    .update({outcome:'error',finished_at:new Date().toISOString()})
    .eq('place_id',placeId).eq('activity',activity);
   return json({summary,place_id:placeId,activity,radius_m:RANGE,
    spots:[],providers:[],photos:[],sources:[],
    tips:['서버 오류가 해결되면 관리자 신고·확인 절차를 이용해 주세요.'],
    temporarily_unavailable:true,cached:false,ai_generated:false});
  }
  const providers=spots.filter(s=>s.phone || s.website).slice(0,12);
  const primary=spots.slice(0,3).map(s=>s.name).join('·');
  const fallback=spots.length>0
   ? (place.name+' 주변 3km 이내 공개지도에 '+spots.length+'곳의 '+activity+' 관련 장소가 확인됩니다. 가까운 곳: '+primary+'.')
   : (place.name+' 주변 3km 이내 공개지도에서 '+activity+' 관련 장소를 확인하지 못했습니다. 정보가 없다는 뜻이지 이용이 불가능하다는 뜻은 아닙니다.');
  let ai:{summary:string,sources:AnyObj[]}|null=null;
  try{
   if(researched && researched.summary && researched.sources?.length){
     // The paid initial AI second-search already ran. Do not bill a second time.
     ai={summary:researched.summary,sources:researched.sources};
   }else if(!researched){
     ai=await onlineAISummary(place.name,activity,spots,Deno.env.get('OPENAI_API_KEY'),db,
       {placeId:place.id,reportId:verifiedReportId,adminId});
   }
  }catch(e){
   if(force)return json({error:String(e).replace(/^Error:\s*/,''),budget_blocked:true},429);
   console.warn('AI lookup skipped:',String(e).slice(0,100));
  }
  if(force && !ai?.summary)return json({error:'AI 검색 또는 출처 확인이 완료되지 않았습니다. 신고는 대기 상태로 유지됩니다.'},503);
  const caution=(activity==='해루질'||activity==='낚시')
   ? '채취·낚시 가능 구역, 출입 제한, 금어기, 기상 및 물때를 현장에서 반드시 확인하세요. 위치 정보만으로 합법적인 이용이 보장되지 않습니다.'
   : activity==='수영'
   ? '강·계곡·하천 물놀이 관련 장소는 후보입니다. 실제 수영 허용 여부, 수심·급류·수질·출입통제 및 기상을 반드시 현장에서 확인하세요.'
   : '운영시간·요금·예약·입장 가능 여부는 출발 전 공식 안내 또는 해당 업체에 확인하세요.';
  const sources=[...spots.map(s=>({name:s.name,url:s.source_url})),...extraSources,...(ai?.sources||[])]
    .filter((s:AnyObj)=>Boolean(validHttp(s.url))).slice(0,26);
  const photos=await photoList(spots);
  const now=new Date().toISOString();
  const record={place_id:place.id,activity,radius_m:RANGE,
   summary:ai?.summary||fallback,spots,providers,photos,tips:[caution],sources,
   fetched_at:now,photo_checked_at:now,expires_at:null,
   research_status:'verified',ai_generated:Boolean(ai?.summary),search_version:5};
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
