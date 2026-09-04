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
}
