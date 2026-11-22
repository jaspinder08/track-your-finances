import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/reports/data/month_report.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

var _id = 0;
Entry _e(
  EntryType type,
  int rupees,
  DateTime date, {
  String? category,
  String? method,
}) => Entry(
  id: '${_id++}',
  createdAt: date,
  updatedAt: date,
  data: EntryDraft(
    type: type,
    amountPaise: rupees * 100,
    date: date,
    category: category,
    paymentMethod: method,
  ),
);

void main() {
  final entries = [
    _e(EntryType.income, 50000, DateTime(2026, 11, 1), category: 'Salary'),
    _e(
      EntryType.expense,
      15000,
      DateTime(2026, 11, 5),
      category: 'Home',
      method: 'UPI',
    ),
    _e(
      EntryType.expense,
      3000,
      DateTime(2026, 11, 8),
      category: 'Food',
      method: 'Cash',
    ),
    _e(
      EntryType.expense,
      2000,
      DateTime(2026, 11, 9),
      category: 'Food',
      method: 'UPI',
    ),
    _e(EntryType.transfer, 9999, DateTime(2026, 11, 9)), // ignored
    _e(EntryType.expense, 16000, DateTime(2026, 10, 3), category: 'Home'),
  ];

  test('totals, savings rate, per day and vs last month', () {
    final r = MonthReport.build(
      entries,
      DateTime(2026, 11),
      now: DateTime(2026, 11, 20),
    );
    expect(r.income, 5000000);
    expect(r.expense, 2000000);
    expect(r.saved, 3000000);
    expect(r.savingsRate, closeTo(0.6, 1e-9));
    expect(r.perDay, 2000000 ~/ 20);
    expect(r.vsLastMonth, closeTo(0.25, 1e-9)); // 20k vs 16k
  });

  test('categories and methods sorted by amount with shares', () {
    final r = MonthReport.build(entries, DateTime(2026, 11));
    expect(r.categories.map((s) => s.name), ['Home', 'Food']);
    expect(r.categories.first.share, closeTo(0.75, 1e-9));
    expect(r.categories.first.emoji, '🏠');
    expect(r.paymentMethods.map((s) => s.name), ['UPI', 'Cash']);
    expect(r.topExpenses.first.amountPaise, 1500000);
  });

  test('trend covers six months ending this month', () {
    final r = MonthReport.build(entries, DateTime(2026, 11));
    expect(r.trend, hasLength(6));
    expect(r.trend.first.month, DateTime(2026, 6));
    expect(r.trend.last.expense, 2000000);
    expect(r.trend[4].expense, 1600000);
  });

  test('past month counts every day; empty month is empty', () {
    final r = MonthReport.build(
      entries,
      DateTime(2026, 10),
      now: DateTime(2026, 11, 20),
    );
    expect(r.daysCounted, 31);
    expect(MonthReport.build(entries, DateTime(2026, 1)).isEmpty, isTrue);
  });
}
