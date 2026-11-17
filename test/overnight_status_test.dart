import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';

void main() {
  test('Checked but unverified overnight parking stays blue with a caution', () {
    final p = Place(
      id: 'x', name: '주차장', latitude: 37, longitude: 127,
      address: 'a', services: ['노지/차박'],
      prices: {'노지/차박': '현장 확인 필요'},
    );
    expect(placeServiceShowsAvailable(p, '노지/차박'), isTrue);
    expect(placeCampingAccessNeedsConfirmation(p), isTrue);
  });

  test('Unchecked camping and explicitly forbidden overnight parking stay neutral', () {
    final unchecked = Place(
      id: 'u', name: '주차장', latitude: 37, longitude: 127,
      address: 'a', services: ['공중화장실'], prices: {},
    );
    final banned = Place(
      id: 'b', name: '주차장', latitude: 37, longitude: 127,
      address: 'a', services: ['노지/차박'],
      prices: {'노지/차박': '차박금지'},
    );
    expect(placeServiceShowsAvailable(unchecked, '노지/차박'), isFalse);
    expect(placeServiceShowsAvailable(banned, '노지/차박'), isFalse);
  });
}
