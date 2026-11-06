import 'package:flutter/services.dart';

/// Comma-groups amounts as they are entered, while preserving "무료" and
/// descriptive price notes such as "캠핑장 이용료 포함".
class PriceThousandsFormatter extends TextInputFormatter {
  const PriceThousandsFormatter();

  static final _numericAmount = RegExp(r'^([0-9,]+)(원)?$');
  static final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

  static String formatStoredText(String value) {
    final input = value.trim();
    final match = _numericAmount.firstMatch(input);
    if (match == null) return value;
    final digits = match.group(1)!.replaceAll(',', '');
    if (digits.isEmpty) return value;
    return digits.replaceAllMapped(_thousands, (_) => ',') +
        (match.group(2) ?? '');
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final match = _numericAmount.firstMatch(newValue.text);
    if (match == null) return newValue; // "무료" and explanatory fees.
    final digits = match.group(1)!.replaceAll(',', '');
    if (digits.isEmpty) return newValue;
    final formatted = formatStoredText(newValue.text);
    if (formatted == newValue.text) return newValue;

    final offset = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final digitsBeforeCaret = RegExp(r'\d')
        .allMatches(newValue.text.substring(0, offset))
        .length;
    var newOffset = 0;
    var digitsSeen = 0;
    while (newOffset < formatted.length && digitsSeen < digitsBeforeCaret) {
      if (RegExp(r'\d').hasMatch(formatted[newOffset])) digitsSeen++;
      newOffset++;
    }
    // If caret was after a unit suffix, retain that position.
    if (offset > match.group(1)!.length) {
      newOffset = formatted.length;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }
}
