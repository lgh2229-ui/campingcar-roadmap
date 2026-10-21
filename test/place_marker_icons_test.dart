import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/widgets/place_marker_icons.dart';

void main() {
  test('four core facilities are shown as a 2 by 2 marker', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실'
    ]);
    expect(icons,const ['💧','DUMP','🅿️','🚻']);
    expect(PlaceMarkerIcons.columns(icons.length),2);
    expect(PlaceMarkerIcons.rows(icons.length),2);
  });

  test('four business services and EV charging expand map to 3 by 3', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '급수','블랙탱크 비움','노지/차박','공중화장실',
      '매매','수리','제작','부품·용품','전기차 충전기',
    ]);
    expect(icons,const ['💧','DUMP','🅿️','🚻','🚐','🔧','🛠️','⚙️','EV']);
    expect(icons.length,9);
    expect(PlaceMarkerIcons.columns(icons.length),3);
    expect(PlaceMarkerIcons.rows(icons.length),3);
    expect(PlaceMarkerIcons.markerHeight(9),greaterThan(PlaceMarkerIcons.markerHeight(4)));
    expect(PlaceMarkerIcons.markerWidth(9),greaterThan(PlaceMarkerIcons.markerWidth(4)));
  });

  test('five categories expand horizontally, then add rows up to nine', () {
    expect(PlaceMarkerIcons.columns(5),3);
    expect(PlaceMarkerIcons.rows(5),2);
    expect(PlaceMarkerIcons.rows(7),3);
    expect(PlaceMarkerIcons.rows(9),3);
  });

  test('tourism and recreation never add category icons', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '급수','관광지','등산','낚시','산책','카지노','지상레포츠','수상레포츠','시장·쇼핑',
    ]);
    expect(icons,const ['💧']);
  });

  test('legacy repair and clean water labels share one icon each', () {
    final icons=PlaceMarkerIcons.fromServices(const [
      '공중화장실','오수','청수','급수','블랙탱크 비움',
      '수리','A/S','정비','매매',
    ]);
    expect(icons,const ['💧','DUMP','🚻','🚐','🔧']);
  });

  test('other-only places remain selectable with neutral pin', () {
    expect(PlaceMarkerIcons.fromServices(const ['관광지','낚시']),const ['📍']);
  });

  test('grouped services preserve every one of the nine categories', () {
    final tags = <String>[
      ...const ['급수','노지/차박','제작','전기차 충전기'],
      ...const ['블랙탱크 비움','공중화장실','매매','A/S','부품·용품'],
    ];
    expect(PlaceMarkerIcons.fromServices(tags).length,9);
  });
}
