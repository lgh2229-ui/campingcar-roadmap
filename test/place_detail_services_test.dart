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
      address:'a',services:['공중화장실'],prices:{'공중화장실':'무료'});
    final withEv = Place(id:'x2',name:'parking',latitude:37,longitude:127,
      address:'a',services:['공중화장실','전기차 충전기'],
      prices:{'공중화장실':'무료'});
    expect(placeServiceShowsAvailable(noEv,'전기차 충전기'),false);
    expect(placeServiceShowsAvailable(withEv,'전기차 충전기'),true);
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
