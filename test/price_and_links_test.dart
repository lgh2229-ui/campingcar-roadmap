import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/widgets/price_thousands_formatter.dart';
import 'package:campingcar_roadmap/widgets/linked_place_note.dart';

void main() {
  const price = PriceThousandsFormatter();

  TextEditingValue changed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  test('digits are grouped every three places while entering', () {
    final result = price.formatEditUpdate(changed(''), changed('1234567'));
    expect(result.text, '1,234,567');
    expect(result.selection.extentOffset, result.text.length);
    expect(price.formatEditUpdate(changed(''), changed('1000원')).text, '1,000원');
    expect(PriceThousandsFormatter.formatStoredText('35000'), '35,000');
    expect(PriceThousandsFormatter.formatStoredText('35000원'), '35,000원');
  });

  test('free and descriptive fees stay exactly as entered', () {
    for (final fee in ['무료', '전화문의', '캠핑장 이용료 포함', '요금 확인 필요']) {
      expect(price.formatEditUpdate(changed(''), changed(fee)).text, fee);
      expect(PriceThousandsFormatter.formatStoredText(fee), fee);
    }
  });

  test('caret remains next to the edited digits', () {
    final typed = TextEditingValue(text: '12500',
        selection: const TextSelection.collapsed(offset: 2));
    final result = price.formatEditUpdate(changed(''), typed);
    expect(result.text, '12,500');
    expect(result.selection.extentOffset, 2);
  });

  test('existing URLs in an ordinary note are recognized without editing', () {
    final links = LinkedPlaceNote.findLinks(
      '공식 안내: https://sites.google.com/view/2mongsanpo/%ED%99%88\n'
      '신청: https://example.org/booking?day=2. 끝.'
    );
    expect(links, [
      'https://sites.google.com/view/2mongsanpo/%ED%99%88',
      'https://example.org/booking?day=2',
    ]);
  });

  testWidgets('tapping an inline URL offers open and copy actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: LinkedPlaceNote(
        text: '문자로 예약하세요. 공식 안내: https://sites.google.com/view/2mongsanpo/%ED%99%88',
      ),
    )));
    final selection = tester.widget<SelectableText>(find.byType(SelectableText));
    final textSpan = selection.textSpan as TextSpan;
    expect(textSpan.toPlainText(), contains('https://sites.google.com/view/2mongsanpo/%ED%99%88'));
    final links = textSpan.children!.whereType<TextSpan>()
        .where((span) => span.recognizer is TapGestureRecognizer).toList();
    expect(links, hasLength(1));
    (links.single.recognizer! as TapGestureRecognizer).onTap?.call();
    await tester.pumpAndSettle();
    expect(find.text('링크 열기'), findsOneWidget);
    expect(find.text('링크 주소 복사'), findsOneWidget);
  });
}
