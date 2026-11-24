import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/utils/nearby_food_naver_link.dart';

void main() {
  group('Nearby food Naver Map search', () {
    test('예촌사랑 + 예산 응봉면, not a foreign location link', () {
      const shop = '예촌사랑';
      const address = '충남 예산군 응봉면 예당관광로 205';
      expect(
        nearbyFoodNaverSearchText(shop, address),
        '예촌사랑 예산 응봉면',
      );
      final app = nearbyFoodNaverAppUri(shop, address);
      expect(app.scheme, 'nmap');
      expect(app.host, 'search');
      expect(app.queryParameters['query'], '예촌사랑 예산 응봉면');
      expect(
        app.queryParameters['appname'],
        'kr.co.campingcarroadmap.app',
      );
      final web = nearbyFoodNaverWebUri(shop, address);
      expect(web.host, 'map.naver.com');
      expect(web.pathSegments.first, 'p');
      expect(web.pathSegments[1], 'search');
      expect(web.pathSegments.last, '예촌사랑 예산 응봉면');
    });
    test('오산시 궐동, strips 시 and retains 동', () {
      expect(
        nearbyFoodNaverSearchText(
          '별밤포차',
          '경기도 오산시 궐동 123-4',
        ),
        '별밤포차 오산 궐동',
      );
    });
    test('부산광역시 영도구, keeps the district', () {
      expect(
        nearbyFoodNaverSearchText(
          '영도 카페',
          '부산광역시 영도구 해양로 74',
        ),
        '영도 카페 영도구',
      );
    });
    test('서울특별시 강남구 역삼동', () {
      expect(
        nearbyFoodNaverSearchText(
          '테스트식당',
          '서울특별시 강남구 역삼동 테헤란로 1',
        ),
        '테스트식당 강남구 역삼동',
      );
    });
    test('avoid repeating street numbers and use bare name without address', () {
      expect(nearbyFoodNaverSearchText('덕브커피', ''), '덕브커피');
      expect(
        nearbyFoodNaverSearchText('돌고래회관', '충남 예산군 응봉면 예당관광로 180'),
        '돌고래회관 예산 응봉면',
      );
    });
  });
}
