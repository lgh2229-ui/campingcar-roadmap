import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/models/recreation_activities.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';

void main() {
  test('Requested activity options are available', () {
    expect(recreationActivities.take(8).toList(), [
      '관광지', '산책', '등산', '낚시',
      '해루질', '수상레포츠', '지상레포츠', '카지노',
    ]);
    expect(recreationActivities.toSet().length, recreationActivities.length);
    expect(recreationActivities, isNot(contains('골프')));
    expect(recreationActivities, isNot(contains('자전거')));
    expect(recreationActivities, isNot(contains('스키·눈썰매')));
    expect(recreationActivities, isNot(contains('캠핑장')));
    expect(recreationActivities, contains('지상레포츠'));
    expect(mergedOrNonTourismActivities, containsAll(['골프','자전거','스키·눈썰매','캠핑장']));
  });

  test('Activity tags round-trip in services without a database migration', () {
    final place = Place(
      id: 'test-activity', name: '바닷가', latitude: 37, longitude: 129,
      address: '강원도 동해시', services: ['노지/차박', '산책', '해루질'],
      prices: {'노지/차박': '무료'},
    );
    final restored = Place.fromJson(place.toJson());
    expect(restored.services, containsAll(['산책', '해루질']));
    expect(restored.prices.containsKey('산책'), isFalse);
    expect(placeServiceShowsAvailable(restored, '해루질'), isTrue);
    expect(placeServiceShowsAvailable(restored, '낚시'), isFalse);
  });
}
