import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/goals/data/goal.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

Goal _goal(int target, int saved, DateTime by, DateTime now) => Goal(
  Entry(
    id: 'g',
    createdAt: now,
    updatedAt: now,
    data: EntryDraft(
      type: EntryType.goal,
      amountPaise: target,
      date: by,
      name: 'Laptop',
      savedSoFarPaise: saved,
    ),
  ),
  now: now,
);

void main() {
  final now = DateTime(2026, 11, 22);

  test('monthly amount spreads what is left over months incl. this one', () {
    final g = _goal(8000000, 2000000, DateTime(2027, 4, 1), now);
    expect(g.monthsLeft, 6); // Nov..Apr
    expect(g.leftPaise, 6000000);
    expect(g.perMonthPaise, 1000000);
    expect(g.ratio, 0.25);
    expect(g.isDone, isFalse);
    expect(g.isOverdue, isFalse);
  });

  test('due this month needs everything now; overdue is flagged', () {
    expect(_goal(10000, 0, DateTime(2026, 11, 30), now).perMonthPaise, 10000);
    final late = _goal(10000, 0, DateTime(2026, 10, 1), now);
    expect(late.isOverdue, isTrue);
    expect(late.monthsLeft, 1);
  });

  test('reached when saved covers target', () {
    final g = _goal(10000, 12000, DateTime(2027, 1, 1), now);
    expect(g.isDone, isTrue);
    expect(g.leftPaise, 0);
    expect(g.perMonthPaise, 0);
  });
}
