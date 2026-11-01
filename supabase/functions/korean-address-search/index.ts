import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import proj4 from "npm:proj4@2.11.0";

const H: Record<string,string> = {
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Content-Type":"application/json; charset=utf-8",
};
const reply = (x:unknown, status=200) => new Response(JSON.stringify(x), {status,headers:H});
const KAKAO_KEY=Deno.env.get("KAKAO_REST_API_KEY")||Deno.env.get("KAKAO_LOCAL_REST_API_KEY")||"";
const NAVER_ID=Deno.env.get("NAVER_MAPS_API_KEY_ID")||Deno.env.get("NAVER_MAPS_CLIENT_ID")||"";
const NAVER_KEY=Deno.env.get("NAVER_MAPS_API_KEY")||Deno.env.get("NAVER_MAPS_CLIENT_SECRET")||"";
const JUSO_KEY=Deno.env.get("JUSO_API_KEY")||"";
const JUSO_COORD_KEY=Deno.env.get("JUSO_COORD_API_KEY")||"";

proj4.defs("EPSG:5179","+proj=tmerc +lat_0=38 +lon_0=127.5 +k=0.9996 +x_0=1000000 +y_0=2000000 +ellps=GRS80 +units=m +no_defs");

const provinceAliases: Record<string,string> = {
  "서울":"서울특별시","부산":"부산광역시","대구":"대구광역시","인천":"인천광역시",
  "광주":"광주광역시","대전":"대전광역시","울산":"울산광역시","세종":"세종특별자치시",
  "경기":"경기도","강원":"강원특별자치도","충북":"충청북도","충남":"충청남도",
  "전북":"전북특별자치도","전남":"전라남도","경북":"경상북도","경남":"경상남도",
  "제주":"제주특별자치도",
  "강원도":"강원특별자치도","전라북도":"전북특별자치도",
};
function normalized(value:string):string {
  let s=String(value||"").trim().replace(/^대한민국\s*/,"").replace(/\s+/g," ");
  const chunks=s.split(" ");
  if(chunks.length && provinceAliases[chunks[0]]) chunks[0]=provinceAliases[chunks[0]];
  return chunks.join("").toLowerCase();
}
function parcelRequest(value:string):boolean {
  return /[가-힣]+(?:동|리)\s*(?:산\s*)?\d+(?:-\d+)?$/.test(value.trim());
}
function matchesParcel(input:string, returned:string):boolean {
  if(!returned || !parcelRequest(input))return false;
  const n=normalized(input), r=normalized(returned);
  // Enforce exactly the supplied numbered parcel and locality; no nearby region or
  // building/address suggestions can silently become a parcel coordinate.
  return r.includes(n) && r.endsWith(n.match(/산?\d+(?:-\d+)?$/)?.[0]||"__NO_PARCEL__");
}
function valid(lat:number,lon:number):boolean {
  return Number.isFinite(lat)&&Number.isFinite(lon)&&lat>=33&&lat<=39&&lon>=124&&lon<=132;
}
type Result={roadAddr:string;jibunAddr:string;zipNo:string;bdNm:string;lat:number;lon:number;source:string;verified:boolean;addressType:string};
function item(road:string,lot:string,lat:number,lon:number,source:string,kind:string,query:string,zipNo="",bdNm=""):Result|null{
  if(!valid(lat,lon))return null;
  if(parcelRequest(query) && !matchesParcel(query,lot))return null;
  if(!parcelRequest(query) && !road && !lot)return null;
  return {roadAddr:road,jibunAddr:lot,zipNo,bdNm,lat,lon,source,verified:parcelRequest(query)?matchesParcel(query,lot):true,addressType:kind};
}
function unique(rows:Result[],seen:Set<string>,row:Result|null){
  if(!row)return;
  const key=normalized(row.jibunAddr||row.roadAddr);
  if(key && !seen.has(key)){seen.add(key);rows.push(row);}
}
async function fetchJSON(url:string,init:RequestInit={},limitMs=4500):Promise<any>{
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),limitMs);
  try{
    const res=await fetch(url,{...init,signal:controller.signal});
    if(!res.ok)throw Error("HTTP_"+res.status);
    return await res.json();
  }finally{clearTimeout(timeout);}
}
async function kakaoSearch(query:string):Promise<Result[]>{
  const url=new URL("https://dapi.kakao.com/v2/local/search/address.json");
  url.searchParams.set("query",query);
  url.searchParams.set("analyze_type","similar");
  url.searchParams.set("size","20");
  const payload=await fetchJSON(url.toString(),{
    headers:{"Authorization":"KakaoAK "+KAKAO_KEY,"Accept":"application/json"}
  });
  const out:Result[]=[],seen=new Set<string>();
  for(const d of (Array.isArray(payload.documents)?payload.documents:[])){
    const address=d.address?.address_name|| (d.address_type==="REGION_ADDR"?d.address_name:"")||"";
    const road=d.road_address?.address_name|| (d.address_type==="ROAD_ADDR"?d.address_name:"")||"";
    // An administrative REGION result is not a street address or a numbered parcel.
    if(d.address_type==="REGION" && !parcelRequest(query))continue;
    unique(out,seen,item(String(road),String(address),Number(d.y),Number(d.x),"kakao",
      d.address_type==="REGION_ADDR"?"parcel":"address",query,
      String(d.road_address?.zone_no||""),String(d.road_address?.building_name||"")));
  }
  return out;
}
async function naverSearch(query:string):Promise<Result[]>{
  const url=new URL("https://maps.apigw.ntruss.com/map-geocode/v2/geocode");
  url.searchParams.set("query",query);
  url.searchParams.set("count","20");
  const payload=await fetchJSON(url.toString(),{
    headers:{"x-ncp-apigw-api-key-id":NAVER_ID,"x-ncp-apigw-api-key":NAVER_KEY,"Accept":"application/json"}
  });
  const out:Result[]=[],seen=new Set<string>();
  for(const d of (Array.isArray(payload.addresses)?payload.addresses:[])){
    const road=String(d.roadAddress||"").trim();
    const lot=String(d.jibunAddress||"").trim();
    unique(out,seen,item(road,lot,Number(d.y),Number(d.x),"naver","address",query));
  }
  return out;
}
async function jusoSearch(query:string):Promise<Result[]>{
  const url=new URL("https://business.juso.go.kr/addrlink/addrLinkApi.do");
  url.search=new URLSearchParams({confmKey:JUSO_KEY,currentPage:"1",countPerPage:"15",keyword:query,resultType:"json",hstryYn:"Y"}).toString();
  const payload=await fetchJSON(url.toString());
  const common=payload?.results?.common||{};
  if(String(common.errorCode||"0")!=="0")throw Error("JUSO_"+String(common.errorCode));
  const out:Result[]=[],seen=new Set<string>();
  for(const d of (Array.isArray(payload?.results?.juso)?payload.results.juso:[]).slice(0,8)){
    const lot=String(d.jibunAddr||"");
    if(parcelRequest(query) && !matchesParcel(query,lot))continue;
    const c=new URL("https://business.juso.go.kr/addrlink/addrCoordApi.do");
    c.search=new URLSearchParams({confmKey:JUSO_COORD_KEY,admCd:String(d.admCd||""),rnMgtSn:String(d.rnMgtSn||""),
      udrtYn:String(d.udrtYn||"0"),buldMnnm:String(d.buldMnnm||"0"),buldSlno:String(d.buldSlno||"0"),resultType:"json"}).toString();
    try{
      const j=await fetchJSON(c.toString(),{},3200);
      const xy=j?.results?.juso?.[0];
      if(!xy?.entX||!xy?.entY)continue;
      const p=proj4("EPSG:5179","EPSG:4326",[Number(xy.entX),Number(xy.entY)]);
      unique(out,seen,item(String(d.roadAddr||d.roadAddrPart1||""),lot,p[1],p[0],"juso","building",query,
        String(d.zipNo||""),String(d.bdNm||"")));
    }catch(e){console.warn("juso coordinates:",String(e).slice(0,70));}
  }
  return out;
}
Deno.serve(async (req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:H});
  if(req.method!=="POST")return reply({error:"POST required"},405);
  let body:Record<string,unknown>;
  try{body=await req.json()}catch{return reply({error:"Invalid JSON"},400)}
  const query=String(body.keyword||"").trim().replace(/\s+/g," ");
  if(!query||query.length>120)return reply({error:"주소 또는 장소명을 120자 이내로 입력해 주세요."},400);
  const rows:Result[]=[],seen=new Set<string>(),failures:string[]=[],available:string[]=[];
  for(const provider of [
    {name:"kakao",ready:Boolean(KAKAO_KEY),run:kakaoSearch},
    {name:"naver",ready:Boolean(NAVER_ID&&NAVER_KEY),run:naverSearch},
    {name:"juso",ready:Boolean(JUSO_KEY&&JUSO_COORD_KEY),run:jusoSearch},
  ]){
    if(!provider.ready)continue;
    available.push(provider.name);
    if(parcelRequest(query)&&rows.length)break;
    try{
      for(const row of await provider.run(query))unique(rows,seen,row);
    }catch(e){
      failures.push(provider.name+":"+String(e).replace(/^Error:\s*/,"").slice(0,45));
    }
    if(rows.length>=12)break;
  }
  if(!available.length)return reply({results:[],status:"provider_unavailable",
    message:"한국 주소 검색 서비스가 연결되어 있지 않습니다."},503);
  return reply({results:rows.slice(0,20),
    status:rows.length?"ok":failures.length===available.length?"provider_unavailable":"no_matching_address",
    isParcelQuery:parcelRequest(query),
    message:rows.length?"주소를 확인했습니다.":parcelRequest(query)?
      "해당 지번의 정확한 좌표를 찾지 못했습니다. 주소가 존재하지 않는다는 뜻은 아닙니다.":
      "일치하는 주소를 찾지 못했습니다.",
    providerErrors:failures,
  });
});