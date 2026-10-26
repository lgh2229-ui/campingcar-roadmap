import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Korean cadastral address lookup: Naver first, Kakao Local API fallback.
// Both credentials are server-only. Never fabricate a parcel number from roads.
const HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json; charset=utf-8",
};
const json = (value:unknown,status=200) =>
  new Response(JSON.stringify(value),{status,headers:HEADERS});
type RegionPart={name?:string};
type NaverResult={
  name?:string;
  region?:Record<string,RegionPart>;
  land?:{type?:string;name?:string;number1?:string;number2?:string};
};
const text = (v:unknown) => String(v??"").trim();
function naverAddress(item:NaverResult,road:boolean):string {
  const reg=item.region||{},land=item.land||{};
  const no1=text(land.number1),no2=text(land.number2);
  if(!/^\d+$/.test(no1)||no1==="0")return "";
  const a=[
    reg.area1?.name, reg.area2?.name, reg.area3?.name,
    ...(road?[land.name]:[reg.area4?.name]),
    (road?"":text(land.type)==="2"?"산 ":"")+no1+
      (no2 && no2!=="0"?"-"+no2:""),
  ];
  return a.filter(Boolean).join(" ").replace(/\s+/g," ").trim();
}
async function fetchNaver(lat:number,lon:number):Promise<{road:string;lot:string;region:string}>{
  const id=Deno.env.get("NAVER_MAPS_API_KEY_ID")||Deno.env.get("NAVER_MAPS_CLIENT_ID");
  const key=Deno.env.get("NAVER_MAPS_API_KEY")||Deno.env.get("NAVER_MAPS_CLIENT_SECRET");
  if(!id||!key)throw new Error("NAVER_NOT_CONFIGURED");
  const url=new URL("https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc");
  url.searchParams.set("coords",lon+","+lat);
  url.searchParams.set("sourcecrs","epsg:4326");
  url.searchParams.set("orders","addr,roadaddr,legalcode");
  url.searchParams.set("output","json");
  const ctl=new AbortController(),timeout=setTimeout(()=>ctl.abort(),4000);
  try{
    const res=await fetch(url.toString(),{
      signal:ctl.signal,
      headers:{"x-ncp-apigw-api-key-id":id,"x-ncp-apigw-api-key":key,Accept:"application/json"},
    });
    if(!res.ok)throw new Error("NAVER_HTTP_"+res.status);
    const payload=await res.json();
    const rows=Array.isArray(payload.results)?payload.results as NaverResult[]:[];
    const addr=rows.find(x=>x.name==="addr");
    const roadaddr=rows.find(x=>x.name==="roadaddr");
    const r=addr?.region||roadaddr?.region||{};
    return {
      road:roadaddr?naverAddress(roadaddr,true):"",
      lot:addr?naverAddress(addr,false):"",
      region:[r.area1?.name,r.area2?.name,r.area3?.name,r.area4?.name]
        .filter(Boolean).join(" "),
    };
  }finally{clearTimeout(timeout)}
}
async function fetchKakao(lat:number,lon:number):Promise<{road:string;lot:string;region:string}>{
  const key=Deno.env.get("KAKAO_REST_API_KEY")||Deno.env.get("KAKAO_LOCAL_REST_API_KEY");
  if(!key)throw new Error("KAKAO_NOT_CONFIGURED");
  const url=new URL("https://dapi.kakao.com/v2/local/geo/coord2address.json");
  url.searchParams.set("x",String(lon));
  url.searchParams.set("y",String(lat));
  url.searchParams.set("input_coord","WGS84");
  const ctl=new AbortController(),timeout=setTimeout(()=>ctl.abort(),4000);
  try{
    const r=await fetch(url.toString(),{
      signal:ctl.signal,headers:{Authorization:"KakaoAK "+key,Accept:"application/json"},
    });
    if(!r.ok){
      // Expose Kakao error code (not credentials) to determine why API access is denied.
      let providerCode="", providerMessage="";
      try {
        const err=await r.json();
        providerCode=String(err.code??"").slice(0,15);
        providerMessage=String(err.msg??err.message??"").replace(/app_key\\([^)]*\\)/gi,"app_key(REDACTED)").slice(0,130);
      }catch(_){}
      throw new Error("KAKAO_HTTP_"+r.status+"_CODE_"+providerCode+"_MSG_"+providerMessage);
    }
    const result=await r.json();
    const item=(Array.isArray(result.documents)?result.documents:[])[0]||{};
    const a=item.address||{},road=item.road_address||{};
    // Require a real cadastral main number; do not accept a bare road/village.
    const main=text(a.main_address_no);
    const parcel=/^\d+$/.test(main)&&main!=="0"?text(a.address_name):"";
    const bnum=text(road.main_building_no);
    const roadAddr=/^\d+$/.test(bnum)&&bnum!=="0"?text(road.address_name):"";
    return {
      lot:parcel,road:roadAddr,
      region:[a.region_1depth_name,a.region_2depth_name,a.region_3depth_name]
        .filter(Boolean).join(" "),
    };
  }finally{clearTimeout(timeout)}
}
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:HEADERS});
  if(req.method!=="POST")return json({error:"POST required"},405);
  let body:Record<string,unknown>;
  try{body=await req.json()}catch{return json({error:"Invalid JSON"},400)}
  const lat=Number(body.latitude),lon=Number(body.longitude);
  if(!Number.isFinite(lat)||!Number.isFinite(lon)||lat<33||lat>39||lon<124||lon>132)
    return json({error:"Invalid Korean coordinates"},400);
  let roadAddr="",jibunAddr="",region="",source="";
  const failed:string[]=[];
  for(const entry of [
    {name:"naver",lookup:()=>fetchNaver(lat,lon)},
    {name:"kakao",lookup:()=>fetchKakao(lat,lon)},
  ]){
    if(roadAddr&&jibunAddr)break;
    try{
      const result=await entry.lookup();
      if(!jibunAddr&&result.lot){jibunAddr=result.lot;source=entry.name;}
      if(!roadAddr&&result.road)roadAddr=result.road;
      if(!region&&result.region)region=result.region;
    }catch(e){
      const reason=String(e).replace(/^Error:\s*/,"");
      failed.push(entry.name+":"+reason.slice(0,70));
      console.warn("parcel reverse provider:",entry.name,reason.slice(0,75));
    }
  }
  // This is an API configuration failure, not "the land parcel does not exist".
  // Never treat unavailable providers as a normal empty parcel lookup.
  if(failed.length===2 && failed.every(x=>x.endsWith("NOT_CONFIGURED"))){
    return json({
      available:false,source:"none",status:"provider_not_configured",
      jibunAddr:"",roadAddr:"",hasFullAddress:false,
      message:"서버 지번조회 API 인증키가 연결되지 않았습니다. 네이버 또는 카카오 주소조회 키 설정이 필요합니다.",
      providerErrors:failed,
    },503);
  }
  return json({
    available:Boolean(jibunAddr),source:source||"none",
    jibunAddr,roadAddr,region,hasFullAddress:Boolean(jibunAddr),
    // The app must never silently replace a missing parcel with a road name.
    message:jibunAddr?"지번 확인":"이 좌표의 지번을 확인할 수 없습니다. 지적도에서 필지를 확인하거나 지번주소를 검색해 지정해 주세요.",
    status:jibunAddr?"verified_parcel":"parcel_unverified",
    providerErrors:failed,
  });
});
