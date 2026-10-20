import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/widgets/place_marker_icons.dart';

void main() {
  test('all four camping services have visible icons without truncation', () {
    final symbols=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실'
    ]);
    expect(symbols.length,4);
    expect(PlaceMarkerIcons.columns(symbols.length),2);
    expect(PlaceMarkerIcons.rows(symbols.length),2);
    expect(symbols,containsAll(const ['💧','🚽','🅿️','🚻']));
  });

  test('more than four available services expand into multiple rows', () {
    final symbols=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실',
      '캠핑장','매매','A/S','부품·용품',
    ]);
    expect(symbols.length,8);
    expect(PlaceMarkerIcons.columns(symbols.length),3);
    expect(PlaceMarkerIcons.rows(symbols.length),3);
    expect(PlaceMarkerIcons.markerWidth(8),greaterThan(52));
    expect(PlaceMarkerIcons.markerHeight(8),greaterThan(52));
  });

  test('activities are not silently discarded from marker service tags', () {
    final symbols=PlaceMarkerIcons.fromServices(const [
      '관광지','산책','등산','낚시','해루질','자전거',
    ]);
    expect(symbols.length,6);
    expect(symbols,containsAll(const ['🏞️','🚶','🥾','🎣','🐚','🚲']));
  });
}
