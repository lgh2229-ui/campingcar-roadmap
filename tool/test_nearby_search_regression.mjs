import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const code = readFileSync('supabase/functions/nearby-activity/index.ts','utf8');

function geographicRootsFromSource() {
  const found = code.match(/function geographicRoots\(full:string\):string\[\]\{[\s\S]*?\n\}/);
  assert.ok(found, 'geographicRoots must exist in live edge function');
  const js = found[0]
    .replace('full:string', 'full')
    .replace('):string[]{', '){');
  return new Function('return (' + js + ')')();
}

test('campground identifiers resolve to the coastal location rather than lot names', () => {
  const roots = geographicRootsFromSource();
  assert.deepEqual(roots('몽산포오토캠핑장2구역'), ['몽산포','몽산포해수욕장']);
  assert.deepEqual(roots('몽산포감성캠핑장'), ['몽산포','몽산포해수욕장']);
  assert.deepEqual(roots('청포대해수욕장 주차장'), ['청포대해수욕장','청포대']);
});

test('coastal and fishing locations remain identifiable', () => {
  const roots=geographicRootsFromSource();
  assert.deepEqual(roots('삼길포항'),['삼길포항','삼길포']);
  assert.deepEqual(roots('당암포구'),['당암포구','당암']);
});

test('port names strip generic docks and still search the named harbor', () => {
  const roots=geographicRootsFromSource();
  assert.deepEqual(roots('만대항 선착장'), ['만대항','만대항선착장','만대']);
  assert.deepEqual(roots('삼길포항 공영주차장'), ['삼길포항','삼길포']);
  assert.deepEqual(roots('당암포구 선착장'), ['당암포구','당암포구선착장','당암']);
  assert.ok(code.includes("roots.flatMap(area=>[area+' 낚시'"));
  assert.ok(code.includes('naverBlogEvidence(place.name,activity)'));
  assert.ok(code.includes('youtubeFishingEvidence(place.name,activity)'));
  assert.ok(code.includes('function fishingPortAnchor('));
});

test('gleaning searches include shellfish, not just generic tourism labels', () => {
  for(const keyword of ['해루질','맛조개','동죽','바지락','백합','갯벌체험','조개잡이']){
    assert.ok(code.includes(keyword), 'search index must include '+keyword);
  }
});

test('unverified blog evidence cannot be turned into a fabricated map pin', () => {
  assert.ok(code.includes('naverBlogEvidence('));
  assert.ok(code.includes('location_verified:false'));
  assert.ok(code.includes('NAVER_SEARCH_CLIENT_ID'));
  assert.ok(code.includes('NAVER_SEARCH_CLIENT_SECRET'));
  assert.ok(code.includes('geographicRoots(placeName)'));
});

test('saved search results bypass external providers regardless of age or version', () => {
  assert.match(code,/SEARCH_VERSION=14/);
  assert.ok(code.includes('if(cache && !force && !refreshSources)'));
  assert.ok(code.includes('return json({...cache,cached:true,search_incomplete:saved.length===0'));
  assert.ok(code.includes('if(body.cache_only===true)'));
  assert.ok(code.includes('return json({cache_miss:true'));
  assert.ok(!code.includes('Number(cache.search_version||0)<SEARCH_VERSION'));
});

test('nearby activities cannot make paid OpenAI API calls', () => {
  assert.doesNotMatch(code, /api\\.openai\\.com/i);
  assert.doesNotMatch(code, /OPENAI_API_KEY/);
  assert.doesNotMatch(code, /reserve_camping_ai_budget/);
  assert.ok(!code.includes('await aiFallback(') && !code.includes('await onlineAISummary('));
});

test('scenic lake and bridge discovery is not restricted to POI business categories', () => {
  assert.ok(code.includes('["natural"="water"]["water"~"^(lake|reservoir)$"]["name"]'));
  assert.ok(code.includes('["man_made"="bridge"]["name"~"출렁다리|구름다리"]'));
  assert.ok(code.includes("region+' 호수'"));
  assert.ok(code.includes("region+' 수변길'"));
  assert.ok(code.includes("region+' 출렁다리'"));
  assert.ok(code.includes('place.address||'));
  assert.ok(code.includes('호수·저수지의 지도 중심점입니다.'));
});

function themedMatcherFromSource(){
  const definition=code.match(/function matchesActivityTheme\(activity:string,nameValue:unknown,kindValue:unknown=''\):boolean\{[\s\S]*?\n\}/);
  assert.ok(definition, 'themed search validator must be in deployed source');
  const javascript=definition[0]
    .replace('activity:string','activity')
    .replace('nameValue:unknown','nameValue')
    .replace("kindValue:unknown=''","kindValue=''")
    .replace('):boolean{','){');
  return new Function('return ('+javascript+')')();
}

test('water sports includes actual beaches and sports, never ordinary lodging',()=>{
  const matches=themedMatcherFromSource();
  for(const name of ['골드오션펜션','마리솔펜션','메르벨르풀빌라','몽산포 황토펜션','오션갤러리']){
    assert.equal(matches('수상레포츠',name,'수상레포츠'),false,name);
  }
  assert.equal(matches('관광지','골드오션펜션','관광지'),false);
  assert.equal(matches('관광지','몽산포해수욕장','관광지'),true);
  assert.equal(matches('수상레포츠','몽산포해수욕장','관광지'),true);
  assert.equal(matches('수상레포츠','죽도해변 서핑','서핑'),true);
  assert.equal(matches('수상레포츠','수주팔봉 달천 강변 물놀이','수상레포츠'),true);
  assert.equal(matches('수상레포츠','한가한 일반 마트','수상레포츠'),false);
});

test('tourism authority beaches can also show under swimming but not hotels',()=>{
  assert.ok(code.includes("const beachSwimming=activity==='수상레포츠'"));
  assert.ok(code.includes("activity==='관광지'"));
  assert.ok(code.includes("matchesActivityTheme(activity,d.place_name,d.category_name)"));
  assert.ok(code.includes("matchesActivityTheme(activity,name,item.kind||'')"));
});
