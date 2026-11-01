import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const registration=readFileSync('tool/fix_place_registration.py','utf8');
const flutter=readFileSync('lib/screens/home_screen.dart','utf8');
const reverse=readFileSync('supabase/functions/korean-reverse-address/index.ts','utf8');
const search=readFileSync('supabase/functions/korean-address-search/index.ts','utf8');

test('parcel lookup checks both authoritative Korean providers',()=>{
 assert.match(reverse,/fetchNaver\(/);
 assert.match(reverse,/fetchKakao\(/);
 assert.match(reverse,/KAKAO_REST_API_KEY/);
 assert.match(reverse,/coord2address\.json/);
 assert.match(reverse,/jibunAddr/);
 assert.match(reverse,/main_address_no/);
 assert.match(reverse,/number1/);
 assert.match(reverse,/parcel_unverified/);
});

test('registration does not assign OSM roads as mandatory cadastral address',()=>{
 assert.match(registration,/await _reverseKoreanParcel\(registrationPoint\)/);
 assert.match(registration,/지번주소 \(필수/);
 assert.match(registration,/!parcelVerified \|\| verifiedParcel\.isEmpty/);
 assert.match(registration,/address\.text\.trim\(\)!=verifiedParcel/);
 assert.doesNotMatch(registration,/final address = TextEditingController\(text: await _reverseAddress/);
 assert.doesNotMatch(registration,/label:const Text\('주소 위치 적용'\)/);
});

test('verified cadastral address positions pin without stale-distance rejection',()=>{
 assert.match(registration,/selected\['verified'\]!=true/);
 assert.match(registration,/registrationPoint=LatLng\(lat,lon\)/);
 assert.doesNotMatch(registration,/if\(meters>200\)/);
 assert.match(registration,/지도에서 직접 위치 지정/);
 assert.match(registration,/registrationPoint=picked/);
 assert.match(registration,/await _reverseKoreanParcel\(picked\)/);
});

test('search accepts numbered land parcels only with matching locality and lot',()=>{
 assert.match(search,/KAKAO_REST_API_KEY/);
 assert.match(search,/NAVER_MAPS_API_KEY_ID/);
 assert.match(search,/search\/address\.json/);
 assert.match(search,/map-geocode\/v2\/geocode/);
 assert.match(search,/matchesParcel\(query,lot\)/);
 assert.match(search,/r\.includes\(n\)/);
 assert.match(search,/parcelRequest\(query\)/);
 assert.match(search,/verified:parcelRequest\(query\)/);
});

test('app searches numbered parcels without trusting approximate OSM positions',()=>{
 assert.match(flutter,/_looksLikeParcelAddress/);
 assert.match(flutter,/addresses\.isEmpty && isParcelAddress/);
 assert.match(flutter,/picked\['verified'\]!=true/);
 assert.match(flutter,/registrationPoint=LatLng\(lat,lon\)/);
});

test('current source and CI-injected source both use same parcel checks',()=>{
 assert.match(flutter,/Future<Map<String, dynamic>> _reverseKoreanParcel/);
 assert.match(flutter,/지번주소 \(필수/);
 assert.match(flutter,/!parcelVerified \|\| verifiedParcel\.isEmpty/);
});
