import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const headers = {
 "Access-Control-Allow-Origin": "*",
 "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
 "Content-Type": "application/json; charset=utf-8",
};
const json = (data:unknown,status=200) => new Response(JSON.stringify(data),{status,headers});
type Item={name?:string,region?:Record<string,{name?:string}>,land?:{type?:string,name?:string,number1?:string,number2?:string}};
function format(item:Item,road:boolean):string {
 const region=item.region||{},land=item.land||{};
 const parts=[region.area1?.name,region.area2?.name,region.area3?.name];
 if(!road && region.area4?.name)parts.push(region.area4.name);
 if(road && land.name)parts.push(land.name);
 const no1=String(land.number1||"").trim();
 const no2=String(land.number2||"").trim();
 if(!no1 || no1==="0")return "";
 parts.push((!road && String(land.type)==="2"?"산 ":"")+no1+
     (no2 && no2!=="0"?"-"+no2:""));
 return parts.filter(Boolean).join(" ").replace(/\\s+/g," ").trim();
}
Deno.serve(async (req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers});
 if(req.method!=="POST")return json({error:"POST required"},405);
 const id=Deno.env.get("NAVER_MAPS_API_KEY_ID")||Deno.env.get("NAVER_MAPS_CLIENT_ID")||"";
 const key=Deno.env.get("NAVER_MAPS_API_KEY")||Deno.env.get("NAVER_MAPS_CLIENT_SECRET")||"";
 // Mobile Naver Maps SDK and server Reverse Geocoding are separately enabled products.
 if(!id||!key)return json({available:false,source:"naver",roadAddr:"",jibunAddr:"",
    message:"NAVER Reverse Geocoding 서버 인증정보 미설정"});
 let body:Record<string,unknown>;
 try{body=await req.json()}catch{return json({error:"Invalid JSON"},400)}
 const lat=Number(body.latitude),lon=Number(body.longitude);
 if(!Number.isFinite(lat)||!Number.isFinite(lon)||lat<33||lat>39||lon<124||lon>132)return json({error:"Invalid Korean coordinates"},400);
 const url=new URL("https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc");
 url.searchParams.set("coords",lon+","+lat);
 url.searchParams.set("sourcecrs","epsg:4326");
 url.searchParams.set("orders","roadaddr,addr,legalcode");
 url.searchParams.set("output","json");
 const ctl=new AbortController(),timeout=setTimeout(()=>ctl.abort(),4700);
 try{
  const res=await fetch(url.toString(),{signal:ctl.signal,headers:{
   "x-ncp-apigw-api-key-id":id,"x-ncp-apigw-api-key":key,
   Accept:"application/json",
  }});
  if(!res.ok)return json({available:false,source:"naver",message:"NAVER reverse geocoding HTTP "+res.status},502);
  const result=await res.json();
  const rows=Array.isArray(result.results)?result.results as Item[]:[];
  const road=rows.find(x=>x.name==="roadaddr");
  const lot=rows.find(x=>x.name==="addr");
  const legal=rows.find(x=>x.name==="legalcode");
  const locality=legal?.region||lot?.region||road?.region||{};
  const region=[locality.area1?.name,locality.area2?.name,locality.area3?.name,locality.area4?.name]
    .filter(Boolean).join(" ");
  const roadAddr=road?format(road,true):"";
  const jibunAddr=lot?format(lot,false):"";
  return json({available:true,source:"naver",roadAddr,jibunAddr,
    region,hasFullAddress:Boolean(roadAddr||jibunAddr)});
 }catch(error){
  console.warn("Naver reverse request failed",String(error).slice(0,100));
  return json({available:false,source:"naver",message:"주소 제공자 연결 실패"},503);
 }finally{clearTimeout(timeout)}
});
