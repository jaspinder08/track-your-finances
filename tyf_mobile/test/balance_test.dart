import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  test('balance counts today and earlier, not future-dated entries', () async {
    final repo = InMemoryEntryRepository();
    final now = DateTime.now();
    Future<void> add(EntryType t, int rupees, DateTime d) => repo.add(
      EntryDraft(type: t, amountPaise: rupees * 100, date: d, category: 'X'),
    );
    await add(EntryType.income, 1000, now.subtract(const Duration(days: 3)));
    await add(
      EntryType.expense,
      200,
      DateTime(now.year, now.month, now.day, 23),
    );
    await add(EntryType.expense, 500, now.add(const Duration(days: 5)));

    final c = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await c.read(entriesProvider.future);
    expect(c.read(balanceProvider), 80000); // 1000 - 200
  });
}
