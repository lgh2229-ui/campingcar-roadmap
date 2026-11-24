import 'package:campingcar_roadmap/utils/food_open_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Times are UTC; Korea is UTC+9 and has no DST.
  test('open and closed follow current Korean local time', () {
    expect(foodOpenState('Mo-Su 09:00-18:00',
        DateTime.utc(2026, 11, 24, 1, 0)), FoodOpenState.open); // Tue 10:00 KST
    expect(foodOpenState('Mo-Su 09:00-18:00',
        DateTime.utc(2026, 11, 24, 10, 0)), FoodOpenState.closed); // Tue 19:00 KST
  });

  test('restaurants open across midnight use previous day correctly', () {
    expect(foodOpenState('Tu 20:00-02:00',
        DateTime.utc(2026, 11, 24, 16, 30)), FoodOpenState.open); // Wed 01:30
    expect(foodOpenState('Tu 20:00-02:00',
        DateTime.utc(2026, 11, 24, 17, 30)), FoodOpenState.closed); // Wed 02:30
    expect(foodOpenState('Tu 20:00-26:00',
        DateTime.utc(2026, 11, 24, 16, 30)), FoodOpenState.open);
  });

  test('breaks and weekly off-days are respected', () {
    const rule = 'Mo-Fr 11:00-14:00,17:00-22:00; Sa 12:00-18:00; Su off';
    expect(foodOpenState(rule, DateTime.utc(2026, 11, 24, 3, 0)),
        FoodOpenState.open); // Tue 12:00
    expect(foodOpenState(rule, DateTime.utc(2026, 11, 24, 6, 0)),
        FoodOpenState.closed); // Tue 15:00 break
    expect(foodOpenState(rule, DateTime.utc(2026, 11, 29, 3, 0)),
        FoodOpenState.closed); // Sun 12:00
  });

  test('24/7 remains open', () {
    expect(foodOpenState('24/7', DateTime.utc(2026, 11, 24)),
        FoodOpenState.open);
  });

  test('unknown, complex holiday, or malformed hours do not invent statuses', () {
    final now = DateTime.utc(2026, 11, 24, 3);
    expect(foodOpenState(null, now), FoodOpenState.unknown);
    expect(foodOpenState('', now), FoodOpenState.unknown);
    expect(foodOpenState('PH off; Mo-Su 10:00-21:00', now),
        FoodOpenState.unknown);
    expect(foodOpenState('by appointment', now), FoodOpenState.unknown);
    expect(foodOpenState('모름', now), FoodOpenState.unknown);
    expect(foodOpenState('Mo-Fr 09:00-??', now), FoodOpenState.unknown);
  });
}
