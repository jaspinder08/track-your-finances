import 'entry.dart';

/// The [n]th occurrence of a series that started on [start].
/// Months and years keep the original day, clamped to the month's length
/// (rent on the 31st lands on 28/29 Feb, then back on 31 Mar).
DateTime occurrence(DateTime start, Repeat r, int n) {
  final step = r.every * n;
  switch (r.unit) {
    case RepeatUnit.day:
      return DateTime(start.year, start.month, start.day + step);
    case RepeatUnit.week:
      return DateTime(start.year, start.month, start.day + 7 * step);
    case RepeatUnit.month:
    case RepeatUnit.year:
      final months = r.unit == RepeatUnit.month ? step : 12 * step;
      final first = DateTime(start.year, start.month + months);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(
        first.year,
        first.month,
        start.day > lastDay ? lastDay : start.day,
      );
  }
}

/// Dates after [after] and up to [today] when the series needs a copy.
/// Capped so a bad rule (e.g. every day for 10 years) can't flood the DB.
List<DateTime> dueDates({
  required DateTime start,
  required Repeat repeat,
  required DateTime after,
  required DateTime today,
  int max = 400,
}) {
  final out = <DateTime>[];
  for (var n = 1; out.length < max; n++) {
    final d = occurrence(start, repeat, n);
    if (d.isAfter(today)) break;
    if (d.isAfter(after)) out.add(d);
  }
  return out;
}
