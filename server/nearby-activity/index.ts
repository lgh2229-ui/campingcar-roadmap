import { createClient } from "npm:@supabase/supabase-js@2.49.10";

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Content-Type": "application/json; charset=utf-8" };
const RANGE = 3000;
type AnyObj = Record<string, any>;
const selectors: Record<string, string[]> = {
  "관광지": ['["tourism"~"^(attraction|museum|viewpoint|zoo|aquarium|gallery)$"]', '["historic"]'],
  "산책": ['["leisure"~"^(park|garden|nature_reserve)$"]','["highway"~"^(path|footway|pedestrian)$"]["name"]','["route"="foot"]'],
  "등산": ['["route"="hiking"]', '["natural"="peak"]', '["information"="guidepost"]'],
  "낚시": ['["sport"="fishing"]','["fishing"]','["shop"="fishing"]','["leisure"="fishing"]'],
  "해루질": ['["natural"~"^(beach|mud)$"]','["wetland"="tidalflat"]'],
  "수상레포츠": ['["sport"~"^(sailing|surfing|canoe|kayaking|kitesurfing|scuba_diving|windsurfing)$"]', '["leisure"="marina"]'],
  "지상레포츠": ['["sport"~"^(climbing|paragliding|archery|motocross|skateboard|horse_racing)$"]','["leisure"="sports_centre"]'],
  "카지노": ['["amenity"="casino"]'],
  "자전거": ['["route"="bicycle"]','["shop"="bicycle"]','["highway"="cycleway"]["name"]'],
  "수영": ['["leisure"="swimming_pool"]','["sport"="swimming"]'],
  "서핑": ['["sport"="surfing"]','["shop"="surf"]'],
  "카약·SUP": ['["sport"~"^(canoe|kayaking|stand_up_paddle)$"]','["canoe"]'],
  "스노클링": ['["sport"~"^(scuba_diving|snorkeling)$"]'],
  "스키·눈썰매": ['["piste:type"]','["sport"="skiing"]'],
  "골프": ['["leisure"="golf_course"]','["sport"="golf"]'],
  "온천·스파": ['["amenity"="public_bath"]','["leisure"="spa"]','["natural"="hot_spring"]'],
  "문화체험": ['["tourism"~"^(museum|gallery)$"]','["amenity"~"^(arts_centre|theatre|community_centre)$"]'],
  "시장·쇼핑": ['["shop"="mall"]','["amenity"="marketplace"]','["shop"="department_store"]'],
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
 };
}
async function curatedPoi(db:any,lat:number,lon:number,activity:string){
 const latDelta=RANGE/110570,lonDelta=RANGE/(111320*Math.max(0.2,Math.cos(lat*Math.PI/180)));
 const {data,error}=await db.from('verified_activity_pois').select('*')
  .eq('activity',activity)
  .gte('latitude',lat-latDelta).lte('latitude',lat+latDelta)
  .gte('longitude',lon-lonDelta).lte('longitude',lon+lonDelta).limit(75);
 if(error)throw error;
 return (data||[]).map((p:AnyObj)=>normalizePlace({
  name:p.name,lat:p.latitude,lon:p.longitude,kind:activity,
  description:p.description,phone:p.phone,website:p.info_source_url,
  source_url:p.info_source_url||p.map_source_url,
 },lat,lon,activity)).filter(Boolean) as AnyObj[];
}
const discoveryKeywords:Record<string,string>={
 '관광지':'관광명소','산책':'산책로 공원','등산':'등산로',
 '낚시':'낚시','해루질':'갯벌', '수상레포츠':'수상레저',
 '지상레포츠':'레포츠','카지노':'카지노', '자전거':'자전거',
 '수영':'수영장','서핑':'서핑','카약·SUP':'카약 SUP',
 '스노클링':'스노클링','스키·눈썰매':'스키장','골프':'골프장',
 '온천·스파':'온천','문화체험':'문화체험','시장·쇼핑':'시장 수산시장'
};
async function kakaoSearch(lat:number,lon:number,activity:string,key:string|undefined){
 if(!key)return [] as AnyObj[];
 const query=discoveryKeywords[activity]||activity;
 const reqUrl='https://dapi.kakao.com/v2/local/search/keyword.json?'+
  new URLSearchParams({query,x:String(lon),y:String(lat),radius:String(RANGE),size:'15',sort:'distance'});
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),6500);
 try{
  const r=await fetch(reqUrl,{headers:{Authorization:'KakaoAK '+key},signal:ctrl.signal});
  if(!r.ok)throw new Error('Kakao '+r.status);
  const body=await r.json();
  return (body.documents||[]).map((d:AnyObj)=>normalizePlace({
   name:d.place_name,lat:d.y,lon:d.x,kind:d.category_name||activity,
   address:d.road_address_name||d.address_name,phone:d.phone,
   website:d.place_url,source_url:d.place_url
  },lat,lon,activity)).filter(Boolean);
 }finally{clearTimeout(timer);}
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
 return {name,lat:la,lon:lo,distance_m:meters,kind:label(t,activity),address:String(t['addr:full']||t['addr:street']||'').slice(0,160),phone,website:safeWebsite,opening_hours:String(t.opening_hours||'').slice(0,120),fee:String(t.fee||'').slice(0,45),description:String(t['description:ko']||t.description||'').slice(0,250),source_url:url};
}
async function optionalAISummary(name:string,activity:string,spots:AnyObj[],key:string|undefined) {
 if(!key)return null;
 const prompt='장소의 주변 활동에 대한 안내를 2~3문장의 한국어로 작성. 오직 제공된 공개지도 POI 데이터로 확인되는 것만 쓰고, 업체 운영/허가/요금/출항여부를 추정하지 마세요. 반경 3km를 반드시 지켜주세요. 해루질은 출입·채취 허가가 확인된 것이 아닙니다. JSON 외 다른 형식을 출력하지 마세요.';
 try {
  const res=await fetch('https://api.openai.com/v1/chat/completions',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+key},body:JSON.stringify({model:'gpt-4o-mini',temperature:0.2,max_tokens:210,response_format:{type:'json_object'},messages:[{role:'system',content:prompt+' 반드시 {"summary":"..."} 형태 JSON을 반환'},{role:'user',content:JSON.stringify({name,activity,spots:spots.slice(0,8).map(s=>({name:s.name,kind:s.kind,distance_m:s.distance_m}))})}]})});
  if(!res.ok)return null;
  const j=await res.json();
  const t=JSON.parse(j.choices?.[0]?.message?.content||'{}').summary;
  return typeof t==='string' ? t.slice(0,450) : null;
 }catch(_){return null;}
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
  if(cache && new Date(cache.expires_at).getTime()>Date.now() && body.force_refresh!==true)return json({...cache,cached:true,ai_generated:Boolean(cache.ai_generated)});
  const lat=Number(place.latitude),lon=Number(place.longitude);
  // Search our existing verified dataset first, even on the very first tap.
  let collected:AnyObj[]=[];
  try{collected=await curatedPoi(db,lat,lon,activity);}catch(e){console.warn('curated POI lookup:',String(e));}
  const errors:string[]=[];
  let lookupSucceeded=collected.length>0;
  // Fresh results are persisted so subsequent opens do not repeat internet searches.
  try{
   const kakao=await kakaoSearch(lat,lon,activity,Deno.env.get('KAKAO_REST_API_KEY'));
   if(kakao.length) {collected.push(...kakao);lookupSucceeded=true;}
  }catch(e){errors.push('지역검색 연결 문제');}
  if(collected.length<12){
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
  const spots=[...unique.values()].sort((a,b)=>a.distance_m-b.distance_m).slice(0,20);
  if(spots.length===0 && !lookupSucceeded){
   // Do not cache an outage as "no attractions" or show a raw HTTP 406/503.
   if(cache)return json({...cache,cached:true,stale:true,warning:'최신 검색 연결이 지연돼 이전 정보를 보여드립니다.'});
   return json({place_id:place.id,activity,radius_m:RANGE,summary:
     '현재 주변 검색 서버 연결이 원활하지 않습니다. 잠시 뒤 다시 검색해주세요. 등록된 활동 정보는 유지됩니다.',
     spots:[],providers:[],tips:['운영 및 출입 가능 여부는 공식 안내에서 확인하세요.'],
     sources:[],temporarily_unavailable:true,warning:errors.join(' · '),cached:false,ai_generated:false});
  }
  const providers=spots.filter(s=>s.phone || s.website).slice(0,12);
  const primary=spots.slice(0,3).map(s=>s.name).join('·');
  const fallback=spots.length>0
   ? (place.name+' 주변 3km 이내 공개지도에 '+spots.length+'곳의 '+activity+' 관련 장소가 확인됩니다. 가까운 곳: '+primary+'.')
   : (place.name+' 주변 3km 이내 공개지도에서 '+activity+' 관련 장소를 확인하지 못했습니다. 정보가 없다는 뜻이지 이용이 불가능하다는 뜻은 아닙니다.');
  const ai=spots.length>0?await optionalAISummary(place.name,activity,spots,Deno.env.get('OPENAI_API_KEY')):null;
  const caution=(activity==='해루질'||activity==='낚시')
   ? '채취·낚시 가능 구역, 출입 제한, 금어기, 기상 및 물때를 현장에서 반드시 확인하세요. 위치 정보만으로 합법적인 이용이 보장되지 않습니다.'
   : '운영시간·요금·예약·입장 가능 여부는 출발 전 공식 안내 또는 해당 업체에 확인하세요.';
  const sources=spots.map(s=>({name:s.name,url:s.source_url})).slice(0,20);
  const record={place_id:place.id,activity,radius_m:RANGE,summary:ai||fallback,spots,providers,tips:[caution],sources,fetched_at:new Date().toISOString(),expires_at:new Date(Date.now()+7*86400*1000).toISOString(),ai_generated:Boolean(ai)};
  const {error:writeError}=await db.from('place_activity_insights').upsert(record,{onConflict:'place_id,activity'});
  if(writeError){return json({...record,warning:'캐시 저장 실패: '+writeError.message,cached:false});}
  if(spots.length>0 && activity!=='해루질') {
   await db.from('place_activity_candidates').upsert({place_id:place.id,activity,radius_m:RANGE,spot_count:spots.length,example_spot:spots[0].name,source_url:spots[0].source_url,updated_at:new Date().toISOString()},{onConflict:'place_id,activity',ignoreDuplicates:true});
  }
  return json({...record,cached:false});
 }catch(e){return json({error:'검색 중 오류가 발생했습니다.',details:String(e).slice(0,150)},500);}
});
