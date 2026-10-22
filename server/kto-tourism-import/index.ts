import {createClient} from "npm:@supabase/supabase-js@2.49.10";

type Obj=Record<string,any>;
const headers={
  "Content-Type":"application/json; charset=utf-8",
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-internal-token",
};
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
const DATASET="https://www.data.go.kr/data/15101578/openapi.do";
const BASE="https://apis.data.go.kr/B551011/KorService2";
const int=(v:unknown,fallback=0)=>Number.isFinite(Number(v))?Number(v):fallback;
const trim=(v:unknown,n=280)=>String(v??"").replace(/<[^>]*>/g," ").replace(/\s+/g," ").trim().slice(0,n);
const safeUrl=(v:unknown)=>{const s=trim(v,700);return /^https:\/\//.test(s)?s:"";};
const dist=(a:number,b:number,c:number,d:number)=>{
 const r=Math.PI/180,x=(c-a)*r,y=(d-b)*r;
 const k=Math.sin(x/2)**2+Math.cos(a*r)*Math.cos(c*r)*Math.sin(y/2)**2;
 return Math.round(12742000*Math.atan2(Math.sqrt(k),Math.sqrt(1-k)));
};
function activityOf(i:Obj):string|null{
 const type=String(i.contenttypeid||"");
 const name=trim(i.title).toLowerCase();
 // TourAPI content type 28 includes camping, golf and snow sports too.
 if(type==="28" || type==="12"){
  if(/캠핑|야영|글램핑|카라반|오토캠프|캠프장|캠프농장|힐링캠프/.test(name))return null; // Campsites are not tourism activities.
  if(/골프|golf|(?:^|[^a-z])(?:gc|cc)(?:$|[^a-z])|컨트리클럽/i.test(name))return "지상레포츠";
 }
 if(type==="28"){
  if(/서핑|서프|수상|카약|요트|카누|수상스키|래프팅|스노클|스노쿨|수영|물놀이|워터파크|sup/.test(name))return "수상레포츠";
  if(/낚시/.test(name))return "낚시";
 if(/해루질|갯벌|조개잡이|맛조개|바지락|동죽|백합|어촌체험/.test(name))return "해루질";
  if(/스키|스노우|스노보드|눈썰매/.test(name))return "지상레포츠";
  if(/산악자전거|자전거|바이크|레일바이크|사이클|mtb/.test(name))return "지상레포츠";
  if(/등산|등반|산행/.test(name))return "등산";
  if(/산책|트레킹|둘레길|해파랑길|바우길|평화길|영남길|탐방로|걷기|호숫길|하늘길/.test(name))return "산책";
  return "지상레포츠";
 }
 if(type==="14")return "문화체험";
 if(type==="38")return "시장·쇼핑";
 if(type!=="12")return null;
 if(/낚시/.test(name))return "낚시";
 if(/해루질|갯벌|조개잡이|맛조개|바지락|동죽|백합|어촌체험/.test(name))return "해루질";
 if(/산책|둘레길|해안길|해변길|탐방로|걷기|트레킹|수변공원|벽화길/.test(name))return "산책";
 if(/등산|등반|산행/.test(name))return "등산";
 return "관광지";
}
function listFromResponse(json:Obj):Obj[]{
 const response=json?.response||{};
 const code=String(response.header?.resultCode??"");
 if(code && code!=="0000")throw Error("관광정보 API 응답 오류 "+code);
 const data=response.body?.items?.item;
 return Array.isArray(data)?data:data && typeof data==="object"?[data]:[];
}
function key(){
 const value=Deno.env.get("KTO_TOUR_API_KEY")||"";
 if(!value)return "";
 try{return value.includes("%")?decodeURIComponent(value):value;}catch{return value;}
}
async function tourCall(endpoint:string,params:Record<string,string|number>):Promise<Obj[]>{
 const k=key();
 if(!k)throw Error("KTO_TOUR_API_KEY not configured");
 const u=new URL(BASE+"/"+endpoint);
 const all:Record<string,string|number>={serviceKey:k,MobileOS:"ETC",MobileApp:"CampingcarRoadmap",_type:"json",...params};
 for(const [name,value] of Object.entries(all))u.searchParams.set(name,String(value));
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),14000);
 try{
  const r=await fetch(u.toString(),{signal:ctrl.signal,headers:{Accept:"application/json"}});
  if(!r.ok)throw Error("관광정보 API HTTP "+r.status);
  const text=await r.text();
  let json:Obj;
  try{json=JSON.parse(text);}catch{throw Error("관광정보 API가 JSON이 아닌 응답을 반환했습니다.");}
  return listFromResponse(json);
 } finally{clearTimeout(timer);}
}
async function licensedPhoto(contentId:string,placeName:string):Promise<Obj[]> {
 if(!/^\d+$/.test(contentId))return [];
 const result=await tourCall("detailImage2",{contentId,numOfRows:8,pageNo:1,imageYN:"Y"});
 const photos:Obj[]=[];
 for(const i of result){
  // Type 1: attribution required, commercial reuse allowed.
  // Type 3: Non-commercial restriction. Do not embed it in an ad-supported app.
  const kind=String(i.cpyrhtDivCd||"").replace(/\s/gi,"").toLowerCase();
  if(!["type1","1","공공누리1유형"].includes(kind))continue;
  const url=safeUrl(i.originimgurl),small=safeUrl(i.smallimageurl)||url;
  if(!url||!small)continue;
  photos.push({
   name:placeName,url,thumbnail_url:small,source_url:DATASET,
   source_name:"한국관광공사 TourAPI",license:"공공누리 제1유형 (출처표시)",
   attribution:"한국관광공사 및 원저작자 (원본 출처 확인)",
   content_id:contentId
  });
  if(photos.length>=2)break;
 }
 return photos;
}

Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
 if(req.method!=="POST")return reply({error:"POST only"},405);
 const client=createClient(Deno.env.get("SUPABASE_URL")||"",
   Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"");
 const internalToken=req.headers.get("x-internal-token")||"";
 let authorized=false;
 if(internalToken){
  const {data}=await client.from("internal_scan_credentials").select("token")
   .eq("task","activity_scan").maybeSingle();
  authorized=Boolean(data?.token&&data.token===internalToken);
 }else{
  const auth=req.headers.get("authorization")||"";
  if(/^Bearer\s+\S+/i.test(auth)){
   const userDb=createClient(Deno.env.get("SUPABASE_URL")||"",
     Deno.env.get("SUPABASE_ANON_KEY")||"",
     {global:{headers:{Authorization:auth}}});
   const {data,error}=await userDb.rpc("is_admin");
   authorized=!error && data===true;
  }
 }
 if(!authorized)return reply({error:"관리자 또는 서버 작업 인증 필요"},403);
 const body=await req.json().catch(()=>({})) as Obj;
 if(body.check_configuration===true){
  // Don't expose the actual API key.
  return reply({kto_key_present:Boolean(key()),api:"KorService2",
    data_source:"한국관광공사 국문 관광정보 서비스",
    max_places_per_run:3,photo_rights:"공공누리 제1유형만"});
 }
 if(!key())return reply({error:"KTO_TOUR_API_KEY 미등록"},503);
 // Admin-only targeted image audit: checks official Korean Open Government
 // Licence type before an image is considered for commercial app display.
 if(body.content_id!==undefined){
  const contentId=String(body.content_id||"");
  if(!/^[0-9]{1,15}$/.test(contentId))return reply({error:"관광 콘텐츠 ID가 올바르지 않습니다."},400);
  try{
   const photos=await licensedPhoto(contentId,trim(body.name||"관광지"));
   return reply({content_id:contentId,licensed_photos:photos,
    notice:"공공누리 제1유형만 반환. 이미지 사용 시 저작자/원본 출처를 확인하세요."});
  }catch(e){return reply({error:"사진 저작권 조회 실패",detail:String(e).slice(0,130)},502);}
 }
 const offset=Math.max(0,Math.min(100000,Math.trunc(int(body.offset))));
 const limit=Math.min(3,Math.max(1,Math.trunc(int(body.limit,2))));
 const {data:places,error}=await client.from("places")
   .select("id,name,latitude,longitude")
   .eq("approval_status","approved")
   .order("id",{ascending:true}).range(offset,offset+limit-1);
 if(error)return reply({error:"장소 목록 조회 실패"},503);
 const report:Obj[]=[];
 for(const place of places||[]){
  const lat=Number(place.latitude),lon=Number(place.longitude);
  if(!Number.isFinite(lat)||!Number.isFinite(lon))continue;
  const stats={place:place.name,scanned:0,inserted:0,photos:0,skipped:0};
  try{
   const items=await tourCall("locationBasedList2",{
    mapX:lon,mapY:lat,radius:3000,arrange:"E",
    numOfRows:65,pageNo:1
   });
   stats.scanned=items.length;
   const grouped=new Map<string,Obj[]>();
   const photoByName=new Map<string,Obj[]>();
   for(const item of items){
    const la=Number(item.mapy),lo=Number(item.mapx);
    const activity=activityOf(item),name=trim(item.title,140);
    const contentId=String(item.contentid||"");
    if(!name||!activity||!/^\d+$/.test(contentId)||!Number.isFinite(la)||!Number.isFinite(lo)){stats.skipped++;continue;}
    const meters=dist(lat,lon,la,lo);
    if(meters>3000){stats.skipped++;continue;}
    const src="https://www.openstreetmap.org/?mlat="+la+"&mlon="+lo+"#map=16/"+la+"/"+lo;
    const description=trim(item.addr1||"")+
      " · 관광공사 TourAPI에 등록된 정보 (ID "+contentId+"). 실제 운영·허용조건은 확인 필요.";
    const spot={
      name,lat:la,lon:lo,distance_m:meters,
      kind:activity,address:trim(item.addr1),
      description,phone:trim(item.tel,70),website:"",
      source_url:DATASET,content_id:contentId
    };
    if(!grouped.has(activity))grouped.set(activity,[]);
    if(!grouped.get(activity)!.some(s=>s.content_id===contentId))grouped.get(activity)!.push(spot);
    const {error:poiError}=await client.from("verified_activity_pois").upsert({
      poi_key:"kto-"+contentId+"-"+activity,name,activity,latitude:la,longitude:lo,
      description:description.slice(0,450),phone:spot.phone,
      map_source_url:src,info_source_url:DATASET,
      verified_at:new Date().toISOString()
    },{onConflict:"poi_key",ignoreDuplicates:true});
    if(poiError)throw poiError;
   }
   // Photos: at most 2 image API queries per place to stay within developer quota.
   let imagesChecked=0;
   for(const [activity,spots] of grouped){
    if(!spots.length)continue;
    let photos:Obj[]=[];
    if(imagesChecked<2){
     for(const spot of spots.slice(0,2)){
      if(imagesChecked>=2)break;
      imagesChecked++;
      try{photos.push(...await licensedPhoto(spot.content_id,spot.name));}
      catch(e){console.warn("Photo query failed",String(e).slice(0,90));}
     }
    }
    const {data:existing, error:lookupError}=await client.from("place_activity_insights")
      .select("summary,spots,photos,research_status")
      .eq("place_id",place.id).eq("activity",activity).maybeSingle();
    if(lookupError)throw lookupError;
    const previous=Array.isArray(existing?.spots)?existing.spots:[];
    const known=new Set(previous.map((s:Obj)=>String(s.content_id||s.name).toLowerCase()));
    const added=spots.filter(s=>!known.has(String(s.content_id||s.name).toLowerCase()));
    const merged=[...previous,...added].filter((s:Obj)=>int(s.distance_m,3001)<=3000).slice(0,35);
    const oldPhotos=Array.isArray(existing?.photos)?existing.photos:[];
    const uniquePhotos=[...oldPhotos,...photos].filter((p:Obj,i,a:Obj[])=>
      a.findIndex(q=>q.url===p.url)===i).slice(0,12);
    const summary=existing?.research_status==="verified" && previous.length>0
      ? existing.summary
      : place.name+" 반경 3km 이내에 한국관광공사에서 제공한 "+activity+
        " 관련 관광정보 "+spots.length+"건이 확인되었습니다. 상세 운영정보는 방문 전 확인해주세요.";
    const {error:saveError}=await client.from("place_activity_insights").upsert({
      place_id:place.id,activity,radius_m:3000,summary,
      spots:merged,photos:uniquePhotos,
      sources:[...new Map(merged.map((s:Obj)=>[
        String(s.content_id||s.name),{name:String(s.name),url:DATASET}
      ])).values()].slice(0,30),
      providers:merged.filter((s:Obj)=>Boolean(s.phone)).slice(0,15),
      tips:["한국관광공사 관광정보를 기반으로 합니다.","노지 차박·급수·오수·낚시의 허용 여부는 이 관광정보만으로 확인되지 않습니다."],
      fetched_at:new Date().toISOString(),expires_at:null,
      research_status:"verified",ai_generated:false,
      photo_checked_at:new Date().toISOString()
    },{onConflict:"place_id,activity"});
    if(saveError)throw saveError;
    stats.inserted+=added.length;stats.photos+=Math.max(0,uniquePhotos.length-oldPhotos.length);
   }
  }catch(e){report.push({...stats,error:String(e).slice(0,200)});continue;}
  report.push(stats);
 }
 return reply({offset,next_offset:offset+(places?.length||0),
   processed:report.length,results:report,
   note:"tourism POIs only; nonverified camping/parking/dump services are not marked as available"});
});
