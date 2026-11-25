import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/insights/insights_sheet.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

Entry e(EntryType t, int rupees, DateTime d, {String cat = 'Food'}) => Entry(
  id: '$t$rupees$d',
  data: EntryDraft(type: t, amountPaise: rupees * 100, date: d, category: cat),
  createdAt: d,
  updatedAt: d,
);

void main() {
  final now = DateTime(2026, 11, 21); // 10 days left
  String? noEmoji(String _) => null;

  test('daily allowance, over budget, biggest spend, savings', () {
    final entries = [
      e(EntryType.income, 50000, DateTime(2026, 11, 1), cat: 'Salary'),
      e(EntryType.expense, 3000, DateTime(2026, 11, 5)),
      e(EntryType.expense, 500, DateTime(2026, 11, 6), cat: 'Travel'),
    ];
    final budgets = [
      const BudgetProgress(
        CategoryBudget(category: 'Food', limitPaise: 200000),
        300000,
        null,
      ),
      const BudgetProgress(
        CategoryBudget(category: 'Travel', limitPaise: 1100000),
        50000,
        null,
      ),
    ];
    final titles = buildInsights(
      entries: entries,
      budgets: budgets,
      emojiFor: noEmoji,
      now: now,
    ).map((i) => i.title).toList();
    // (13,000 - 3,500) / 10 days left
    expect(titles, contains('₹950 a day'));
    expect(titles, contains('Nothing spent today'));
    expect(titles, contains('Food is over budget'));
    expect(titles, contains('Food is your biggest spend'));
    expect(titles, contains('Saving 93% of your income'));
  });

  test('nothing yet: asks for transactions', () {
    final list = buildInsights(
      entries: const [],
      budgets: const [],
      emojiFor: noEmoji,
      now: now,
    );
    expect(list.map((i) => i.title), contains('Add a few transactions'));
  });
}
