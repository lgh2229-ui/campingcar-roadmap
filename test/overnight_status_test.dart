import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';
void main() {
  test('Unverified overnight parking is neutral', () {
    final p=Place(id:'x',name:'주차장',latitude:37,longitude:127,address:'a',services:['노지/차박'],prices:{'노지/차박':'현장 확인 필요'});
    expect(placeServiceShowsAvailable(p,'노지/차박'),false);
  });
}
