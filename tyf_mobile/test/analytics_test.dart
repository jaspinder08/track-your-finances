import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/analytics/analytics_data.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

var _id = 0;
Entry e(EntryType t, int rupees, DateTime d, {String? cat, String? pay}) =>
    Entry(
      id: '${_id++}',
      data: EntryDraft(
        type: t,
        amountPaise: rupees * 100,
        date: d,
        category: cat,
        paymentMethod: pay,
      ),
      createdAt: d,
      updatedAt: d,
    );

void main() {
  final now = DateTime(2026, 11, 26);
  final entries = [
    e(EntryType.income, 17000, DateTime(2026, 11, 1)),
    e(EntryType.expense, 8000, DateTime(2026, 11, 3), cat: 'Home', pay: 'UPI'),
    e(
      EntryType.expense,
      4000,
      DateTime(2026, 11, 9),
      cat: 'Shopping',
      pay: 'Cash',
    ),
    // October: saved 3,000.
    e(EntryType.income, 10000, DateTime(2026, 10, 1)),
    e(EntryType.expense, 7000, DateTime(2026, 10, 5), cat: 'Food', pay: 'UPI'),
    // Earlier this year.
    e(EntryType.expense, 1000, DateTime(2026, 2, 2), cat: 'Food', pay: 'UPI'),
  ];

  test('this month: totals, categories, savings vs last month', () {
    final d = AnalyticsData.compute(
      entries,
      AnalyticsPeriod.thisMonth,
      now: now,
    );
    expect(d.income, 1700000);
    expect(d.expense, 1200000);
    expect(d.saved, 500000);
    expect(d.categories.map((s) => s.name), ['Home', 'Shopping']);
    expect(d.categories.first.share, closeTo(0.667, 0.01));
    expect(d.paymentMethods.first.name, 'UPI');
    expect(d.savedChange, closeTo(2 / 3, 0.01)); // 5,000 vs 3,000
    expect(d.months, hasLength(6));
    expect(d.months.last.expense, 1200000);
  });

  test('last 6 months and this year cover the right spans', () {
    final six = AnalyticsData.compute(
      entries,
      AnalyticsPeriod.last6Months,
      now: now,
    );
    expect(six.expense, 1900000); // Oct + Nov, not Feb
    final year = AnalyticsData.compute(
      entries,
      AnalyticsPeriod.thisYear,
      now: now,
    );
    expect(year.expense, 2000000);
    expect(year.months, hasLength(11)); // Jan–Nov
  });
}
