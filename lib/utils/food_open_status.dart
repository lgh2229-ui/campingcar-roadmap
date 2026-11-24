/// A conservative current-hours interpretation for nearby food listings.
/// Times are business-local Asia/Seoul time (KST, UTC+09:00).
/// Do not confuse this with a real-time on-site occupancy check.
enum FoodOpenState { open, closed, unknown }

class _DailyInterval {
  const _DailyInterval(this.startMinute, this.endMinute);
  final int startMinute;
  final int endMinute;
}

const _weekdayCodes = <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

Set<int>? _parseWeekdays(String? text) {
  if (text == null || text.isEmpty) return {0, 1, 2, 3, 4, 5, 6};
  final out = <int>{};
  for (final part in text.split(',')) {
    final values = part.split('-');
    if (values.isEmpty || values.length > 2) return null;
    final start = _weekdayCodes.indexOf(values.first);
    final end = _weekdayCodes.indexOf(values.last);
    if (start < 0 || end < 0) return null;
    var day = start;
    out.add(day);
    while (day != end) {
      day = (day + 1) % 7;
      out.add(day);
    }
  }
  return out;
}

_DailyInterval? _parseInterval(String text) {
  final match = RegExp(r'^(\d{1,2}):([0-5]\d)-(\d{1,2}):([0-5]\d)$')
      .firstMatch(text.trim());
  if (match == null) return null;
  final fromH = int.parse(match.group(1)!);
  final fromM = int.parse(match.group(2)!);
  final toH = int.parse(match.group(3)!);
  final toM = int.parse(match.group(4)!);
  if (fromH > 23 || toH > 48 || (toH == 48 && toM != 0)) {
    return null;
  }
  final start = fromH * 60 + fromM;
  var end = toH * 60 + toM;
  if (start == end) return null; // Ambiguous; no claim of open/closed.
  if (end < start) end += 24 * 60; // After midnight.
  return _DailyInterval(start, end);
}

/// Calculates an approximate status from an explicit weekly hours rule.
/// Accepts standard weekly rules like:
/// 24/7, Mo-Su 10:00-21:00, Mo-Fr 09:00-18:00; Sa 09:00-15:00; Su off.
/// Unknown/complex holiday rules return [FoodOpenState.unknown] rather than
/// inventing a status. [utcNow] is injectable to enable deterministic tests.
FoodOpenState foodOpenState(String? openingHours, DateTime utcNow) {
  final text = (openingHours ?? '').trim();
  if (text.isEmpty) return FoodOpenState.unknown;
  if (text == '24/7') return FoodOpenState.open;
  // Holidays, seasonal/solar schedules, appointments, comments, and
  // unsupported OSM rules must not be misreported as regular opening hours.
  if (RegExp(r'\b(PH|SH|sunrise|sunset|appointment|unknown)\b',
          caseSensitive: false).hasMatch(text) ||
      text.contains('"') || text.contains('||') ||
      text.contains('+') || text.contains('week ')) {
    return FoodOpenState.unknown;
  }

  final byDay = List.generate(7, (_) => <_DailyInterval>[]);
  final prefix = RegExp(
    r'^((?:Mo|Tu|We|Th|Fr|Sa|Su)(?:[-,](?:Mo|Tu|We|Th|Fr|Sa|Su))*)\s+',
  );
  for (final rawClause in text.split(';')) {
    final clause = rawClause.trim();
    if (clause.isEmpty) return FoodOpenState.unknown;
    final dayMatch = prefix.firstMatch(clause);
    final days = _parseWeekdays(dayMatch?.group(1));
    if (days == null) return FoodOpenState.unknown;
    final remaining =
        (dayMatch == null ? clause : clause.substring(dayMatch.end)).trim();

    final ranges = <_DailyInterval>[];
    if (remaining != 'off' && remaining != 'closed') {
      for (final section in remaining.split(',')) {
        final interval = _parseInterval(section);
        if (interval == null) return FoodOpenState.unknown;
        ranges.add(interval);
      }
    }
    // Later rules replace earlier rules for the same day (OSM precedence).
    for (final day in days) {
      byDay[day] = ranges;
    }
  }

  // Seoul has no daylight saving time; convert UTC to KST before evaluating.
  final kst = utcNow.toUtc().add(const Duration(hours: 9));
  final index = kst.weekday - 1; // Monday = 0
  final prevIndex = (index + 6) % 7;
  final minute = kst.hour * 60 + kst.minute;
  for (final interval in byDay[index]) {
    if (minute >= interval.startMinute && minute < interval.endMinute) {
      return FoodOpenState.open;
    }
  }
  for (final interval in byDay[prevIndex]) {
    final shifted = minute + 1440;
    if (shifted >= interval.startMinute &&
        shifted < interval.endMinute) {
      return FoodOpenState.open;
    }
  }
  return FoodOpenState.closed;
}
