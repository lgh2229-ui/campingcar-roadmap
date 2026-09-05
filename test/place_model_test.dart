import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';

void main() {
  test('Place parses Supabase fields and serializes service data', () {
    final place = Place.fromJson({
      'id': 'p1',
      'name': '테스트 장소',
      'latitude': 37.1,
      'longitude': 127.1,
      'address': '경기도 오산시 내삼미로 89',
      'services': ['급수', '블랙탱크 비움'],
      'prices': {'priceWater': '무료', 'priceBlack': '5000'},
      'max_height_mm': 3000,
      'inquiry_phone': '01012345678',
      'photo_urls': ['https://example.com/a.jpg'],
    });

    expect(place.maxHeightMm, 3000);
    expect(place.phone, '01012345678');
    expect(place.services, contains('급수'));
    expect(place.photoUrls.length, 1);
    final row = place.toSupabaseJson();
    expect(row['max_height_mm'], 3000);
    expect(row['inquiry_phone'], '01012345678');
  });

  test('height compatibility keeps a 100mm default safety buffer', () {
    final place = Place(
      id: 'height-1',
      name: '높이 제한 장소',
      latitude: 37.0,
      longitude: 127.0,
      address: '테스트 주소',
      services: const ['노지/차박'],
      prices: const {},
      maxHeightMm: 3100,
    );

    expect(place.isHeightCompatible(3000), isTrue);
    expect(place.isHeightCompatible(3050), isFalse);
    expect(place.heightSafetyLabel(3050), contains('진입 주의'));
  });

  test('unknown height data never hides a place', () {
    final unrestricted = Place(
      id: 'height-2',
      name: '높이 정보 없음',
      latitude: 37.0,
      longitude: 127.0,
      address: '테스트 주소',
      services: const ['급수'],
      prices: const {},
    );

    expect(unrestricted.isHeightCompatible(3300), isTrue);
    expect(unrestricted.heightSafetyLabel(3300), '높이 제한 정보 없음');
  });
}
