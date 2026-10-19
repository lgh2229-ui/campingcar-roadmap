import { createClient } from "npm:@supabase/supabase-js@2.49.10";
const HEADERS={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Content-Type":"application/json; charset=utf-8"};
const send=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:HEADERS});
function distance(a:number,b:number,c:number,d:number) {
 const r=Math.PI/180,d1=(c-a)*r,d2=(d-b)*r;
 const x=Math.sin(d1/2)**2+Math.cos(a*r)*Math.cos(c*r)*Math.sin(d2/2)**2;
 return 12742000*Math.atan2(Math.sqrt(x),Math.sqrt(1-x));
}
function classify(t:Record<string,string>):string[] {
 const out=new Set<string>();
 if(t.tourism && /^(attraction|viewpoint|museum|aquarium|zoo|gallery)$/.test(t.tourism))out.add("관광지");
 if(t.historic)out.add("관광지");
 if(/^(park|garden|nature_reserve)$/.test(t.leisure||"") || (t.name && /^(path|footway)$/.test(t.highway||"")) || t.route==="foot")out.add("산책");
 if(t.route==="hiking" || t.natural==="peak")out.add("등산");
 if(t.sport==="fishing" || t.shop==="fishing" || t.fishing==="yes")out.add("낚시");
 // Beach/mud alone does not demonstrate legal shellfish harvesting: never infer 해루질.
 if(/^(sailing|surfing|canoe|kayaking|windsurfing|kitesurfing)$/.test(t.sport||""))out.add("수상레포츠");
 if(/^(climbing|paragliding|archery|motocross|skateboard)$/.test(t.sport||""))out.add("지상레포츠");
 if(t.amenity==="casino")out.add("카지노");
 if(t.route==="bicycle" || t.shop==="bicycle")out.add("자전거");
 if(t.leisure==="swimming_pool" || t.sport==="swimming")out.add("수영");
 if(t.sport==="surfing" || t.shop==="surf")out.add("서핑");
 if(/^(canoe|kayaking|stand_up_paddle)$/.test(t.sport||""))out.add("카약·SUP");
 if(/^(snorkeling|scuba_diving)$/.test(t.sport||""))out.add("스노클링");
 if(t["piste:type"] || t.sport==="skiing")out.add("스키·눈썰매");
 if(t.leisure==="golf_course" || t.sport==="golf")out.add("골프");
 if(t.leisure==="spa" || t.natural==="hot_spring")out.add("온천·스파");
 if(/^(museum|gallery)$/.test(t.tourism||"") || /^(arts_centre|theatre)$/.test(t.amenity||""))out.add("문화체험");
 if(t.amenity==="marketplace" || /^(mall|department_store)$/.test(t.shop||""))out.add("시장·쇼핑");
 return [...out];
}
const filters=[
 '["tourism"~"^(attraction|viewpoint|museum|aquarium|zoo|gallery)$"]',
 '["historic"]','["leisure"~"^(park|garden|nature_reserve|sports_centre|swimming_pool|golf_course|spa)$"]',
 '["route"~"^(foot|hiking|bicycle)$"]','["natural"="peak"]',
 '["shop"~"^(fishing|bicycle|surf|mall|department_store)$"]',
 '["sport"~"^(fishing|sailing|surfing|canoe|kayaking|windsurfing|kitesurfing|climbing|paragliding|archery|motocross|skateboard|swimming|snorkeling|scuba_diving|skiing|golf|stand_up_paddle)$"]',
 '["amenity"~"^(casino|marketplace|arts_centre|theatre)$"]',
 '["piste:type"]', '["natural"="hot_spring"]'
];
async function lookup(lat:number,lon:number) {
 const query='[out:json][timeout:22];('+filters.map(f=>'nwr(around:3000,'+lat+','+lon+')'+f+';').join('')+');out center 400;';
 const urls=['https://overpass.kumi.systems/api/interpreter','https://overpass-api.de/api/interpreter'];
 for(const url of urls){
  const controller=new AbortController(), timeout=setTimeout(()=>controller.abort(),13000);
  try {
   const res=await fetch(url,{method:'POST',headers:{"Content-Type":"application/x-www-form-urlencoded"},body:'data='+encodeURIComponent(query),signal:controller.signal});
   if(!res.ok)continue;
   const json=await res.json();
   if(Array.isArray(json.elements))return json.elements as Record<string,any>[];
  }catch(_){/* try fallback */}finally{clearTimeout(timeout);}
 }
 throw new Error('공개지도 검색 서버 응답 실패');
}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:HEADERS,status:204});
 if(req.method!=='POST')return send({error:'POST only'},405);
 try{
  const auth=req.headers.get('authorization')||'';
  if(!/^Bearer\s+\S+/i.test(auth))return send({error:'인증 필요'},401);
  const url=Deno.env.get('SUPABASE_URL')||'';
  const adminKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  const userDb=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')||'',{global:{headers:{Authorization:auth}}});
  const {data:isAdmin,error:authError}=await userDb.rpc('is_admin');
  if(authError||isAdmin!==true)return send({error:'관리자 전용'},403);
  const db=createClient(url,adminKey);
  const input=await req.json().catch(()=>({}));
  const offset=Math.max(0,Math.min(100000,Number(input.offset)||0));
  const limit=3;
  const {data:places,error}=await db.from('places').select('id,name,latitude,longitude')
    .eq('approval_status','approved').order('id',{ascending:true}).range(offset,offset+limit-1);
  if(error)throw error;
  const {count}=await db.from('places').select('id',{count:'exact',head:true}).eq('approval_status','approved');
  const results=[];
  for (const p of places||[]){
   const elements=await lookup(Number(p.latitude),Number(p.longitude));
   const candidates=new Map<string,{name:string,url:string,count:number}>();
   for(const e of elements){
    const tags=e.tags||{},name=String(tags['name:ko']||tags.name||'').trim();
    const la=Number(e.lat??e.center?.lat),lo=Number(e.lon??e.center?.lon);
    if(!name||!Number.isFinite(la)||!Number.isFinite(lo))continue;
    if(distance(Number(p.latitude),Number(p.longitude),la,lo)>3000)continue;
    for(const activity of classify(tags)){
     const src='https://www.openstreetmap.org/'+e.type+'/'+e.id;
     if(!candidates.has(activity))candidates.set(activity,{name,url:src,count:1});
     else candidates.get(activity)!.count+=1;
    }
   }
   const rows=[...candidates.entries()].map(([activity,x])=>({
    place_id:p.id, activity, radius_m:3000,spot_count:x.count,
    example_spot:x.name,source_url:x.url,updated_at:new Date().toISOString(),
   }));
   if(rows.length) {
    const {error:saveError}=await db.from('place_activity_candidates').upsert(rows,{onConflict:'place_id,activity',ignoreDuplicates:true});
    if(saveError)throw saveError;
   }
   results.push({place:p.name,found:rows.length});
  }
  return send({offset,next_offset:offset+(places?.length||0),total:count||0,has_more:offset+(places?.length||0)<(count||0),results});
 }catch(e){return send({error:String(e).slice(0,300)},503);}
});
