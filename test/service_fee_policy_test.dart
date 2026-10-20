import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/service_fee_policy.dart';

void main() {
  test('EV charger fee input is optional', () {
    expect(placeEditRequiresFee('전기차 충전기'), false);
  });
  test('priced facilities still need fee input', () {
    for (final x in ['급수','블랙탱크 비움','노지/차박','공중화장실']) {
      expect(placeEditRequiresFee(x),true);
    }
  });
  test('other checkbox-only services need no fee input', () {
    for (final x in ['수리','제작','매매','부품·용품','낚시']) {
      expect(placeEditRequiresFee(x), false);
    }
  });
}
