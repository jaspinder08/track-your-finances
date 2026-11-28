import 'package:flutter/foundation.dart';

import '../../transactions/data/entry.dart';
import '../../transactions/data/transaction_options.dart';

/// Totals for one category (or payment method) in a month.
@immutable
class Slice {
  const Slice(this.name, this.paise, this.share, {this.emoji});
  final String name;
  final int paise;

  /// 0..1 of the month's expenses.
  final double share;
  final String? emoji;
}

/// Income vs expense for one month, for the trend chart.
@immutable
class MonthTotals {
  const MonthTotals(this.month, this.income, this.expense);
  final DateTime month;
  final int income;
  final int expense;
}

/// Everything the Reports tab shows for one month, computed from entries.
@immutable
class MonthReport {
  const MonthReport._({
    required this.month,
    required this.income,
    required this.expense,
    required this.previousExpense,
    required this.categories,
    required this.paymentMethods,
    required this.topExpenses,
    required this.trend,
    required this.daysCounted,
  });

  final DateTime month;
  final int income;
  final int expense;

  /// Last month's expenses, for the "vs last month" badge.
  final int previousExpense;
  final List<Slice> categories;
  final List<Slice> paymentMethods;
  final List<Entry> topExpenses;

  /// Six months ending with [month], oldest first.
  final List<MonthTotals> trend;

  /// Days elapsed in the month (all days for past months).
  final int daysCounted;

  int get saved => income - expense;
  double? get savingsRate => income == 0 ? null : saved / income;
  int get perDay => daysCounted == 0 ? 0 : expense ~/ daysCounted;
  bool get isEmpty => income == 0 && expense == 0;

  /// Change in spending vs last month, e.g. 0.12 = 12% more.
  double? get vsLastMonth => previousExpense == 0
      ? null
      : (expense - previousExpense) / previousExpense;

  factory MonthReport.build(
    List<Entry> entries,
    DateTime month, {
    DateTime? now,
    String? Function(String name)? emojiFor,
  }) {
    final emoji =
        emojiFor ??
        (String n) =>
            expenseCategories.where((c) => c.name == n).firstOrNull?.emoji;
    final today = now ?? DateTime.now();
    bool inMonth(Entry e, DateTime m) =>
        e.date.year == m.year && e.date.month == m.month;
    int sum(Iterable<Entry> es) => es.fold(0, (s, e) => s + e.amountPaise);

    final m = DateTime(month.year, month.month);
    final thisMonth = entries.where((e) => inMonth(e, m)).toList();
    final expenses = thisMonth
        .where((e) => e.type == EntryType.expense)
        .toList();
    final expense = sum(expenses);
    final income = sum(thisMonth.where((e) => e.type == EntryType.income));

    List<Slice> group(String Function(Entry) key, {bool withEmoji = false}) {
      final totals = <String, int>{};
      for (final e in expenses) {
        totals[key(e)] = (totals[key(e)] ?? 0) + e.amountPaise;
      }
      final list = [
        for (final t in totals.entries)
          Slice(
            t.key,
            t.value,
            expense == 0 ? 0 : t.value / expense,
            emoji: withEmoji ? emoji(t.key) : null,
          ),
      ]..sort((a, b) => b.paise.compareTo(a.paise));
      return list;
    }

    final prev = DateTime(m.year, m.month - 1);
    final trend = [
      for (var i = 5; i >= 0; i--)
        () {
          final mm = DateTime(m.year, m.month - i);
          final es = entries.where((e) => inMonth(e, mm));
          return MonthTotals(
            mm,
            sum(es.where((e) => e.type == EntryType.income)),
            sum(es.where((e) => e.type == EntryType.expense)),
          );
        }(),
    ];

    final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
    final isCurrent = today.year == m.year && today.month == m.month;
    final isFuture = m.isAfter(DateTime(today.year, today.month));

    return MonthReport._(
      month: m,
      income: income,
      expense: expense,
      previousExpense: sum(
        entries.where((e) => e.type == EntryType.expense && inMonth(e, prev)),
      ),
      categories: group((e) => e.data.category ?? 'Other', withEmoji: true),
      paymentMethods: group((e) => e.data.paymentMethod ?? 'Other'),
      topExpenses:
          (List.of(expenses)
                ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise)))
              .take(5)
              .toList(),
      trend: trend,
      daysCounted: isFuture ? 0 : (isCurrent ? today.day : daysInMonth),
    );
  }
}
