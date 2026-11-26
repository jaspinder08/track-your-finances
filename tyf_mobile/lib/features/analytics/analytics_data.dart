import '../reports/data/month_report.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/transaction_options.dart';

/// The span the Analytics tab looks at.
enum AnalyticsPeriod {
  thisMonth('This Month'),
  last6Months('Last 6 Months'),
  thisYear('This Year');

  const AnalyticsPeriod(this.label);
  final String label;
}

/// Everything the Analytics tab shows, worked out from entries.
class AnalyticsData {
  const AnalyticsData({
    required this.period,
    required this.income,
    required this.expense,
    required this.previousSaved,
    required this.categories,
    required this.paymentMethods,
    required this.months,
  });

  final AnalyticsPeriod period;
  final int income;
  final int expense;

  /// Savings in the period just before, for "compared to last …".
  final int previousSaved;
  final List<Slice> categories;
  final List<Slice> paymentMethods;

  /// Income and expense per month, oldest first (6 months, or Jan–now
  /// for This Year), for the bar and trend charts.
  final List<MonthTotals> months;

  int get saved => income - expense;

  /// Change in savings vs the previous period (0.29 = 29% more), or null
  /// if there's nothing to compare with.
  double? get savedChange =>
      previousSaved == 0 ? null : (saved - previousSaved) / previousSaved.abs();

  /// Share of income kept, 0..1 (null without income).
  double? get savingsRate =>
      income == 0 ? null : (saved / income).clamp(0, 1).toDouble();

  bool get isEmpty => income == 0 && expense == 0;

  factory AnalyticsData.compute(
    List<Entry> entries,
    AnalyticsPeriod period, {
    DateTime? now,
    String? Function(String name)? emojiFor,
  }) {
    final t = now ?? DateTime.now();
    final thisMonth = DateTime(t.year, t.month);
    final (start, end, prevStart) = switch (period) {
      AnalyticsPeriod.thisMonth => (
        thisMonth,
        DateTime(t.year, t.month + 1),
        DateTime(t.year, t.month - 1),
      ),
      AnalyticsPeriod.last6Months => (
        DateTime(t.year, t.month - 5),
        DateTime(t.year, t.month + 1),
        DateTime(t.year, t.month - 11),
      ),
      AnalyticsPeriod.thisYear => (
        DateTime(t.year),
        DateTime(t.year + 1),
        DateTime(t.year - 1),
      ),
    };

    bool within(Entry e, DateTime a, DateTime b) =>
        !e.isDeleted && !e.date.isBefore(a) && e.date.isBefore(b);
    int sum(Iterable<Entry> es, EntryType type) =>
        es.where((e) => e.type == type).fold(0, (s, e) => s + e.amountPaise);

    final inPeriod = entries.where((e) => within(e, start, end)).toList();
    final before = entries.where((e) => within(e, prevStart, start)).toList();
    final income = sum(inPeriod, EntryType.income);
    final expense = sum(inPeriod, EntryType.expense);

    List<Slice> group(String Function(Entry) key, {bool withEmoji = false}) {
      final totals = <String, int>{};
      for (final e in inPeriod.where((e) => e.type == EntryType.expense)) {
        totals[key(e)] = (totals[key(e)] ?? 0) + e.amountPaise;
      }
      return [
        for (final x in totals.entries)
          Slice(
            x.key,
            x.value,
            expense == 0 ? 0 : x.value / expense,
            emoji: withEmoji ? emojiFor?.call(x.key) : null,
          ),
      ]..sort((a, b) => b.paise.compareTo(a.paise));
    }

    final firstChartMonth = period == AnalyticsPeriod.thisYear
        ? DateTime(t.year)
        : DateTime(t.year, t.month - 5);
    final months = <MonthTotals>[];
    for (
      var m = firstChartMonth;
      !m.isAfter(thisMonth);
      m = DateTime(m.year, m.month + 1)
    ) {
      final es = entries.where(
        (e) => within(e, m, DateTime(m.year, m.month + 1)),
      );
      months.add(
        MonthTotals(m, sum(es, EntryType.income), sum(es, EntryType.expense)),
      );
    }

    return AnalyticsData(
      period: period,
      income: income,
      expense: expense,
      previousSaved:
          sum(before, EntryType.income) - sum(before, EntryType.expense),
      categories: group((e) => e.data.category ?? 'Other', withEmoji: true),
      paymentMethods: group((e) => e.data.paymentMethod ?? 'Other'),
      months: months,
    );
  }
}
