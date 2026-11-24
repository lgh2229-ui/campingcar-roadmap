import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/utils/nearby_food_ranking.dart';

void main() {
  test('unscored place must never be presented as number 1 just for proximity', () {
    expect(verifiedNearbyFoodRank(null, 1), isNull);
    expect(verifiedNearbyFoodRank(null, 13), isNull);
  });

  test('rank is shown only for businesses with a verified dining score', () {
    expect(verifiedNearbyFoodRank(71, 1), 1);
    expect(verifiedNearbyFoodRank(60, 7), 7);
    expect(verifiedNearbyFoodRank(50, null), isNull);
  });
}
