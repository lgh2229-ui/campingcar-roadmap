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
async function overpass(lat:number, lon:number, keys:string[]) {
 const query='[out:json][timeout:23];('+keys.map(k=>'nwr(around:'+RANGE+','+lat+','+lon+')'+k+';').join('')+');out center 400;';
 const endpoints=['https://overpass.kumi.systems/api/interpreter','https://overpass-api.de/api/interpreter'];
 let lastError='';
 for(const url of endpoints) {
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),14000);
  try {
   const res=await fetch(url,{method:'POST',body:'data='+encodeURIComponent(query),headers:{'Content-Type':'application/x-www-form-urlencoded'},signal:controller.signal});
   if (!res.ok) {lastError='공개 지도 서버 HTTP '+res.status;continue;}
   const data=await res.json();
   if(!Array.isArray(data.elements))throw new Error('invalid Overpass response');
   return data.elements as AnyObj[];
  }catch(e){lastError=String(e);}finally{clearTimeout(timer);}
 }
 throw new Error('주변 정보 출처에 일시적으로 접속할 수 없습니다. '+lastError.slice(0,90));
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
  let elements:AnyObj[]=[];
  try{elements=await overpass(lat,lon,selectors[activity]);}
  catch(e){if(cache)return json({...cache,cached:true,stale:true,warning:String(e)});return json({error:String(e)},503);}
  const unique=new Map<string,AnyObj>();
  for(const e of elements) {
   const spot=spotFromElement(e,lat,lon,activity);
   if(spot && !unique.has(spot.name))unique.set(spot.name,spot);
  }
  const spots=[...unique.values()].sort((a,b)=>a.distance_m-b.distance_m).slice(0,20);
  const providers=spots.filter(s=>s.phone || s.website).slice(0,12);
  const primary=spots.slice(0,3).map(s=>s.name).join('·');
  const fallback=spots.length>0
   ? (place.name+' 주변 3km 이내 공개지도에 '+spots.length+'곳의 '+activity+' 관련 장소가 확인됩니다. 가까운 곳: '+primary+'.')
   : (place.name+' 주변 3km 이내 공개지도에서 '+activity+' 관련 장소를 확인하지 못했습니다. 정보가 없다는 뜻이지 이용이 불가능하다는 뜻은 아닙니다.');
  const ai=await optionalAISummary(place.name,activity,spots,Deno.env.get('OPENAI_API_KEY'));
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
