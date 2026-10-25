import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/models/place_review.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';

void main() {
  test('Selected facilities with unknown fees remain available', () {
    final p = Place(id: 'sample', name: 'sample', latitude: 0, longitude: 0,
      address: 'sample',
      services: ['노지/차박', '공중화장실', '블랙탱크 비움'],
      prices: {
        '노지/차박': '요금 확인 필요',
        '공중화장실': '캠핑장 이용료 포함',
        '블랙탱크 비움': '캠핑장 숙박 이용료 포함 / 외부 단독이용 요금 확인 필요',
      });
    expect(placeServiceShowsAvailable(p, '노지/차박'), true);
    expect(placeServiceShowsAvailable(p, '공중화장실'), true);
    expect(placeServiceShowsAvailable(p, '블랙탱크 비움'), true);
    expect(placeServiceShowsAvailable(p, '급수'), false);
    final u = Place(id: 'unknown', name: 'parking', latitude: 0, longitude: 0,
      address: 'parking', services: ['노지/차박'],
      prices: {'노지/차박': '주차 무료 / 차박 허용 여부 미확인'});
    expect(placeServiceShowsAvailable(u, '노지/차박'), false);
  });
  test('EV charging availability follows the saved services checkbox', () {
    final noEv = Place(id:'x1',name:'parking',latitude:37,longitude:127,
      address:'a',services:['공중화장실','노지/차박'],prices:{'공중화장실':'무료','노지/차박':'무료'});
    final withEv = Place(id:'x2',name:'parking',latitude:37,longitude:127,
      address:'a',services:['공중화장실','노지/차박','전기차 충전기'],
      prices:{'공중화장실':'무료'});
    expect(placeServiceShowsAvailable(noEv,'전기차 충전기'),false);
    expect(placeServiceShowsAvailable(withEv,'전기차 충전기'),true);
  });

  test('Campgrounds are part of 노지/차박 and keep their paid prices', () {
    final campsite = Place(
      id: 'paid-campground', name: '자동차야영장',
      latitude: 37, longitude: 127, address: 'test',
      services: ['노지/차박', '공중화장실'],
      prices: {'노지/차박': '유료 35,000원 (1박)'},
    );
    final legacy = Place(
      id: 'legacy-campground', name: '구버전 캠핑장',
      latitude: 37, longitude: 127, address: 'test',
      services: ['캠핑장'], prices: {'캠핑장': '유료 30,000원'},
    );
    final unverified = Place(
      id: 'tent-only', name: '텐트야영장', latitude: 37, longitude: 127,
      address: 'test', services: ['노지/차박'],
      prices: {'노지/차박': '유료 캠핑장 · 캠핑카 진입·차박 허용 여부 미확인'},
    );
    expect(placeServiceShowsAvailable(campsite, '노지/차박'), true);
    expect(placeServiceShowsAvailable(legacy, '노지/차박'), true);
    // The registered campground exists, even if campervan admission
    // still needs on-site confirmation (blue card with an info icon).
    expect(placeServiceShowsAvailable(unverified, '노지/차박'), true);
  });

  test('Ulleung Hakpo paid campground is listed despite unknown campervan entry', () {
    final place = Place(
      id: 'ulleung-hakpo',
      name: '울릉도 학포야영장',
      latitude: 37.49, longitude: 130.90,
      address: '경상북도 울릉군 서면 태하리 420',
      services: ['관광지','노지/차박'],
      prices: {
        '노지/차박': '유료 야영장 · 요금·예약 현장 확인 · 캠핑카 진입·차박 허용 여부 미확인',
      },
    );
    expect(placeServiceShowsAvailable(place, '노지/차박'), isTrue);
    expect(placeServiceShowsAvailable(place, '전기차 충전기'), isFalse);
    final prohibited = Place(
      id: 'prohibited-campground', name: '차박 금지 캠핑장',
      latitude: 37, longitude: 127, address: 'test',
      services: ['노지/차박'], prices: {'노지/차박': '유료 캠핑장 · 차박금지'},
    );
    expect(placeServiceShowsAvailable(prohibited, '노지/차박'), isFalse);
    final uncheckedParking = Place(
      id: 'parking', name: '주차장',
      latitude: 37, longitude: 127, address: 'test',
      services: ['노지/차박'],
      prices: {'노지/차박': '주차 무료 / 차박 허용 여부 미확인'},
    );
    expect(placeServiceShowsAvailable(uncheckedParking, '노지/차박'), isFalse);
  });

  testWidgets('Ulleung campground card is blue with caution info rather than approval check',
      (tester) async {
    final place = Place(
      id: 'ulleung-hakpo-ui', name: '울릉도 학포야영장',
      latitude: 37.49, longitude: 130.90,
      address: '경상북도 울릉군 서면 태하리 420',
      services: ['관광지','노지/차박'],
      prices: {'노지/차박':
        '유료 야영장 · 요금·예약 현장 확인 · 캠핑카 진입·차박 허용 여부 미확인'},
      approvalStatus: 'approved',
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlaceDetailSheet(
        place: place,
        scrollController: controller,
        reviews: const <PlaceReview>[],
        initiallySaved: false,
        isAdministrator: false,
        onSetSaved: (_) async => true,
        onReview: () {},
        onEdit: () {},
        onDelete: () {},
        onOpenAddress: () {},
        onPhotoTap: (_) {},
        photoBuilder: (_) => const SizedBox(),
        reviewBuilder: (_) => const SizedBox(),
      )),
    ));
    final fee = find.text(
      '유료 야영장 · 요금·예약 현장 확인 · 캠핑카 진입·차박 허용 여부 미확인');
    expect(fee, findsOneWidget);
    final ancestors = tester.widgetList<Container>(
      find.ancestor(of: fee, matching: find.byType(Container)),
    );
    expect(ancestors.any((c) => c.decoration is BoxDecoration &&
      (c.decoration! as BoxDecoration).color == const Color(0xFFEAF4FF)), isTrue);
    expect(find.byIcon(Icons.info_outline_rounded), findsWidgets);
  });

  testWidgets('Pinned coordinates and three navigation buttons remain in every detail sheet',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final place = Place(
      id: 'precise-spot',
      name: '청포대해수욕장 주차장',
      latitude: 36.6382566184732,
      longitude: 126.303249095008,
      address: '충청남도 태안군 별주부길',
      services: ['노지/차박'],
      prices: {'노지/차박': '무료'},
      approvalStatus: 'approved',
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PlaceDetailSheet(
        place: place,
        scrollController: controller,
        reviews: const <PlaceReview>[],
        initiallySaved: false,
        isAdministrator: false,
        onSetSaved: (_) async => true,
        onReview: () {},
        onEdit: () {},
        onDelete: () {},
        onOpenAddress: () {},
        onPhotoTap: (_) {},
        photoBuilder: (_) => const SizedBox(),
        reviewBuilder: (_) => const SizedBox(),
      ),
    )));
    expect(find.text('상세주소 미확인 · 지정한 정확한 핀 위치'), findsOneWidget);
    expect(find.text('36.6382566, 126.3032491'), findsOneWidget);
    expect(find.text('주소 대신 이 좌표로 정확한 위치를 확인하세요'), findsOneWidget);
    expect(find.text('앱 지도에서 보기'), findsOneWidget);
    expect(find.text('티맵'), findsOneWidget);
    expect(find.text('카카오맵'), findsOneWidget);
    expect(find.text('네이버지도'), findsOneWidget);
  });

  testWidgets('Full Korean road addresses are primary and do not show GPS box',
    (tester) async {
    final controller=ScrollController();
    addTearDown(controller.dispose);
    final place=Place(id:'numbered-road',name:'일반 캠핑장',
      latitude:37.1,longitude:127.2,
      address:'경기도 수원시 영통구 광교로 100',
      services:['노지/차박'],prices:{'노지/차박':'유료'},approvalStatus:'approved');
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PlaceDetailSheet(
      place:place,scrollController:controller,
      reviews:const <PlaceReview>[],initiallySaved:false,isAdministrator:false,
      onSetSaved:(_)async=>true,onReview:(){},onEdit:(){},onDelete:(){},
      onOpenAddress:(){},onPhotoTap:(_){},
      photoBuilder:(_)=>const SizedBox(),reviewBuilder:(_)=>const SizedBox(),
    ))));
    expect(find.text('한국 주소'), findsOneWidget);
    expect(find.text('경기도 수원시 영통구 광교로 100'),findsOneWidget);
    expect(find.text('상세주소 미확인 · 지정한 정확한 핀 위치'),findsNothing);
    expect(find.text('네이버지도'),findsOneWidget);
  });

  test('EV must be an amenity of an overnight place, not a standalone category', () {
    final onlyCharger = Place(
      id:'ev-only', name:'독립 충전소', latitude:37,longitude:127,
      address:'test', services:['전기차 충전기'],prices:{},
    );
    final campsiteWithCharger = Place(
      id:'with-ev', name:'차박과 충전이 가능한 곳',latitude:37,longitude:127,
      address:'test',services:['노지/차박','전기차 충전기'],prices:{'노지/차박':'무료'},
    );
    expect(placeServiceShowsAvailable(onlyCharger,'전기차 충전기'),false);
    expect(placeServiceShowsAvailable(campsiteWithCharger,'전기차 충전기'),true);
  });

  testWidgets('Facility and camper business cards stay visible with correct status',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final place = Place(
      id: 'test-place',
      name: '테스트 캠핑장',
      latitude: 37.1,
      longitude: 127.1,
      address: '테스트 주소',
      services: ['노지/차박', '매매', 'A/S'],
      prices: {
        '노지/차박': '차박 허용 여부 미확인',
      },
      approvalStatus: 'approved',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlaceDetailSheet(
          place: place,
          scrollController: controller,
          reviews: const <PlaceReview>[],
          initiallySaved: false,
          isAdministrator: false,
          onSetSaved: (_) async => true,
          onReview: () {},
          onEdit: () {},
          onDelete: () {},
          onOpenAddress: () {},
          onPhotoTap: (_) {},
          photoBuilder: (_) => const SizedBox(),
          reviewBuilder: (_) => const SizedBox(),
        ),
      ),
    ));

    expect(find.text('이용 가능 시설'), findsOneWidget);
    expect(find.text('차박 허용 여부 미확인'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('캠핑카 서비스'), findsOneWidget);
    expect(find.text('매매'), findsWidgets);
    expect(find.text('A/S · 수리'), findsOneWidget);
    expect(find.text('제작'), findsOneWidget);
    expect(find.text('부품 / 용품'), findsOneWidget);
    expect(find.text('서비스 가능'), findsNWidgets(2));
    expect(find.text('정보 없음'), findsNWidgets(3)); // Includes unconfirmed EV charger.

    // Selected & confirmed service: light-blue. Unknown service: neutral.
    final availableCards = tester.widgetList<Container>(find.ancestor(
      of: find.text('매매').last,
      matching: find.byType(Container),
    ));
    expect(
      availableCards.any((element) =>
          (element.decoration is BoxDecoration) &&
          (element.decoration! as BoxDecoration).color == const Color(0xFFEAF4FF)),
      isTrue,
    );

    final unknownCards = tester.widgetList<Container>(find.ancestor(
      of: find.text('제작'),
      matching: find.byType(Container),
    ));
    expect(
      unknownCards.any((element) =>
          (element.decoration is BoxDecoration) &&
          (element.decoration! as BoxDecoration).color == const Color(0xFFEAF4FF)),
      isFalse,
    );
  });
}
