import 'package:campingcar_roadmap/models/place.dart';
import 'package:campingcar_roadmap/models/place_review.dart';
import 'package:campingcar_roadmap/widgets/place_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Food appears as a tourism tile, not a standalone section',
      (tester) async {
    final place = Place(
      id: 'marino-camp',
      name: '영도 마리노 오토캠핑장',
      latitude: 35.1021476,
      longitude: 129.061384,
      address: '부산광역시 영도구 해양로 13-16',
      services: ['노지/차박', '공중화장실'],
      prices: {'노지/차박': '30,000원'},
      approvalStatus: 'approved',
    );
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlaceDetailSheet(
        place: place,
        scrollController: scroll,
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
    final tile = find.text('주변맛집');
    await tester.scrollUntilVisible(
      tile, 300, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tile, findsOneWidget);
    expect(find.text('반경 1km · 자동 검색 · 점수 확인 매장 우선 · 최대 20곳'), findsNothing);
    expect(find.textContaining('다이닝코드'), findsNothing);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('반경 1km · 자동 검색 · 점수 확인 매장 우선 · 최대 20곳'), findsOneWidget);
    expect(find.textContaining('다이닝코드'), findsNothing);
    expect(find.text('내 맛집 추천하기'), findsOneWidget);
    expect(find.text('주변 맛집 검색'), findsNothing);
  });
}
