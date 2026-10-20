import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/widgets/place_marker_icons.dart';

void main() {
  test('the four core campervan services are the only map category icons', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실',
    ]);
    expect(icons, const ['💧','🚽','🅿️','🚻']);
    expect(PlaceMarkerIcons.columns(icons.length),2);
    expect(PlaceMarkerIcons.rows(icons.length),2);
  });

  test('leisure, tourism, markets and commercial categories do not add icons', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실',
      '캠핑장','매매','A/S','부품·용품',
      '관광지','산책','등산','낚시','해루질','자전거',
      '지상레포츠','수상레포츠','카지노','시장·쇼핑',
    ]);
    expect(icons, const ['💧','🚽','🅿️','🚻']);
    expect(PlaceMarkerIcons.rows(icons.length),2);
    expect(PlaceMarkerIcons.markerWidth(icons.length),lessThanOrEqualTo(65));
    expect(PlaceMarkerIcons.markerHeight(icons.length),lessThanOrEqualTo(65));
  });

  test('aliases are deduplicated and the icon order remains fixed', () {
    expect(PlaceMarkerIcons.fromServices(const [
      '공중화장실','오수','청수','급수','블랙탱크 비움','노지/차박',
    ]),const ['💧','🚽','🅿️','🚻']);
  });

  test('places with only tourism or business services keep a neutral pin', () {
    expect(PlaceMarkerIcons.fromServices(const ['관광지','낚시','매매']),
      const ['📍']);
  });

  test('grouped places share only the four campervan icons', () {
    final grouped=PlaceMarkerIcons.fromServices(
      [const ['노지/차박','관광지'],const ['공중화장실','급수','시장·쇼핑']]
        .expand((services)=>services),
    );
    expect(grouped,const ['💧','🅿️','🚻']);
  });
}
