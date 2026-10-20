import { createClient } from "npm:@supabase/supabase-js@2.49.10";
const HEADERS={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info, x-internal-token","Content-Type":"application/json; charset=utf-8"};
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
  const url=Deno.env.get('SUPABASE_URL')||'';
  const adminKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  const db=createClient(url,adminKey);
  const internalToken=req.headers.get('x-internal-token')||'';
  let authorized=false;
  if(internalToken) {
    const {data:job}=await db.from('internal_scan_credentials').select('token').eq('task','activity_scan').maybeSingle();
    authorized=Boolean(job?.token && internalToken===job.token);
  } else if(/^Bearer\s+\S+/i.test(auth)){
    const userDb=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')||'',{global:{headers:{Authorization:auth}}});
    const {data:isAdmin,error:authError}=await userDb.rpc('is_admin');
    authorized=!authError && isAdmin===true;
  }
  if(!authorized)return send({error:'관리자 또는 서버 작업 인증 필요'},403);
  const input=await req.json().catch(()=>({}));
  // Authenticated non-billable configuration check. Never return secret contents.
  // Zero-generation credential/permission diagnostic: an intentionally invalid
  // Responses request should return HTTP 400 only after auth succeeds.
  if(input.check_openai_access===true){
    const key=Deno.env.get('OPENAI_API_KEY')||'';
    if(!key)return send({openai_status:'missing_key'});
    try{
      const controller=new AbortController();
      const timer=setTimeout(()=>controller.abort(),10000);
      try{
        const response=await fetch('https://api.openai.com/v1/responses',{
          method:'POST',
          headers:{'Authorization':'Bearer '+key,'Content-Type':'application/json'},
          body:'{}',
          signal:controller.signal,
        });
        const status=response.status;
        return send({
          openai_status:status===400?'authenticated_responses_endpoint':
            status===401?'invalid_key':
            status===403?'permission_denied':
            status===429?'billing_or_rate_limit':
            status===200?'unexpected_success':
            'unexpected_http_'+status,
          http_status:status,
          generated_tokens:0,
        });
      }finally{clearTimeout(timer);}
    }catch(e){
      return send({openai_status:'connectivity_error',detail:String(e).slice(0,120)});
    }
  }
  if(input.check_configuration===true){
    const {data:settings,error:settingsError}=await db.from('camping_ai_budget_settings')
      .select('budget_monthly_krw,enabled,refresh_requires_report').eq('id',1).maybeSingle();
    return send({
      openai_key_present:Boolean(Deno.env.get('OPENAI_API_KEY')),
      kakao_local_search_key_present:Boolean(Deno.env.get('KAKAO_REST_API_KEY')),
      ai_budget_ready:!settingsError && settings?.enabled===true &&
        settings?.budget_monthly_krw===30000 &&
        settings?.refresh_requires_report===true,
      budget_monthly_krw:settings?.budget_monthly_krw??null,
    });
  }
  const offset=Math.max(0,Math.min(100000,Number(input.offset)||0));
  const limit=3;
  const {data:places,error}=await db.from('places').select('id,name,latitude,longitude')
    .eq('approval_status','approved').order('id',{ascending:true}).range(offset,offset+limit-1);
  if(error)throw error;
  const {count}=await db.from('places').select('id',{count:'exact',head:true}).eq('approval_status','approved');
  const results=[];
  for (const p of places||[]){
   try {
    const elements=await lookup(Number(p.latitude),Number(p.longitude));
    const grouped=new Map<string,Map<string,Record<string,any>>>();
    for(const e of elements){
     const tags=e.tags||{},name=String(tags['name:ko']||tags.name||'').trim();
     const la=Number(e.lat??e.center?.lat),lo=Number(e.lon??e.center?.lon);
     if(!name||!Number.isFinite(la)||!Number.isFinite(lo))continue;
     const distance_m=Math.round(distance(Number(p.latitude),Number(p.longitude),la,lo));
     if(distance_m>3000)continue;
     const source_url='https://www.openstreetmap.org/'+e.type+'/'+e.id;
     const phone=String(tags['contact:phone']||tags.phone||'').slice(0,80);
     const website=String(tags['contact:website']||tags.website||'').slice(0,220);
     const entry={name,lat:la,lon:lo,distance_m,kind:String(tags.tourism||tags.sport||tags.leisure||tags.shop||tags.amenity||'주변 활동'),
      address:String(tags['addr:full']||tags['addr:street']||'').slice(0,160),
      description:String(tags['description:ko']||tags.description||'').slice(0,300),
      phone,website:(website.startsWith('https://') || website.startsWith('http://'))?website:'',

      fee:String(tags.fee||'').slice(0,60),opening_hours:String(tags.opening_hours||'').slice(0,100),source_url};
     for(const activity of classify(tags)){
      if(!grouped.has(activity))grouped.set(activity,new Map());
      const bucket=grouped.get(activity)!;
      if(!bucket.has(name))bucket.set(name,entry);
     }
    }
    const candidates=[];
    const cache=[];
    for(const [activity,poi] of grouped.entries()){
      const sorted=[...poi.values()].sort((a,b)=>a.distance_m-b.distance_m).slice(0,20);
      if(!sorted.length)continue;
      const near=sorted.slice(0,3).map(x=>x.name).join(' · ');
      candidates.push({place_id:p.id,activity,radius_m:3000,spot_count:poi.size,
        example_spot:sorted[0].name,source_url:sorted[0].source_url,
        updated_at:new Date().toISOString()});
      cache.push({place_id:p.id,activity,radius_m:3000,
        summary:p.name+' 반경 3km 이내에서 '+activity+' 관련 공개지도 장소 '+poi.size+'곳이 확인되었습니다. 가까운 장소: '+near+'. 실사용 및 운영 상태는 출발 전에 확인해주세요.',
        spots:sorted,providers:sorted.filter(x=>x.phone||x.website),
        tips:[activity==='낚시'?'낚시점은 선상낚시 출항 업체로 확인된 것이 아닙니다. 낚시 가능 장소와 금어기·출항 예약은 따로 확인해주세요.':activity==='해루질'?'해루질 허용 및 채취 권한 여부는 별도 확인이 필요합니다.':'운영시간·이용료·출입 허용 여부는 방문 전 실제 운영처에 확인하세요.'],
        sources:sorted.map(x=>({name:x.name,url:x.source_url})),
        fetched_at:new Date().toISOString(),
        expires_at:null,
        ai_generated:false});
    }
    if(candidates.length){
     const {error:e}=await db.from('place_activity_candidates').upsert(candidates,{onConflict:'place_id,activity',ignoreDuplicates:true});
     if(e)throw e;
     const {error:c}=await db.from('place_activity_insights').upsert(cache,{onConflict:'place_id,activity',ignoreDuplicates:true});
     if(c)throw c;
    }
    results.push({place:p.name,found:candidates.length,status:'ok'});
   } catch(e){
    results.push({place:p.name,found:0,status:'error',message:String(e).slice(0,110)});
   }
  }
  return send({offset,next_offset:offset+(places?.length||0),total:count||0,has_more:offset+(places?.length||0)<(count||0),results});
 }catch(e){return send({error:String(e).slice(0,300)},503);}
});
