import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/models/place_review.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';

void main() {
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
    expect(find.text('정보 없음'), findsNWidgets(2));

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
