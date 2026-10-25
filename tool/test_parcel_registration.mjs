import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const registration=readFileSync('tool/fix_place_registration.py','utf8');
const flutter=readFileSync('lib/screens/home_screen.dart','utf8');
const reverse=readFileSync('supabase/functions/korean-reverse-address/index.ts','utf8');

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

test('manual cadastral address verification never moves the picked GPS pin',()=>{
 assert.match(registration,/Geolocator\.distanceBetween/);
 assert.match(registration,/if\(meters>200\)/);
 assert.match(registration,/지도에서 직접 위치 지정/);
 assert.match(registration,/registrationPoint=picked/);
 assert.match(registration,/await _reverseKoreanParcel\(picked\)/);
 assert.match(registration,/지정한 핀 좌표는 바꾸지 않았습니다/);
});

test('current source and CI-injected source both use same parcel checks',()=>{
 assert.match(flutter,/Future<Map<String, dynamic>> _reverseKoreanParcel/);
 assert.match(flutter,/지번주소 \(필수/);
 assert.match(flutter,/!parcelVerified \|\| verifiedParcel\.isEmpty/);
});
