import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/recurrence.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  const monthly = Repeat(every: 1, unit: RepeatUnit.month);

  group('occurrence', () {
    test('month-end clamps then returns to the 31st', () {
      final start = DateTime(2026, 1, 31);
      expect(occurrence(start, monthly, 1), DateTime(2026, 2, 28));
      expect(occurrence(start, monthly, 2), DateTime(2026, 3, 31));
      expect(occurrence(start, monthly, 3), DateTime(2026, 4, 30));
    });
    test('days, weeks, years', () {
      final s = DateTime(2024, 2, 29);
      expect(
        occurrence(s, const Repeat(every: 3, unit: RepeatUnit.day), 1),
        DateTime(2024, 3, 3),
      );
      expect(
        occurrence(s, const Repeat(every: 2, unit: RepeatUnit.week), 1),
        DateTime(2024, 3, 14),
      );
      expect(
        occurrence(s, const Repeat(every: 1, unit: RepeatUnit.year), 1),
        DateTime(2025, 2, 28),
      );
    });
  });

  group('createDueRecurring', () {
    EntryDraft rent(DateTime date, {Repeat? repeat = monthly}) => EntryDraft(
      type: EntryType.expense,
      amountPaise: 1500000,
      date: date,
      name: 'Rent',
      category: 'Home',
      subcategory: 'Rent',
      paymentMethod: 'UPI',
      repeat: repeat,
    );

    test('back-dated rent fills missed months up to today, once', () async {
      final repo = InMemoryEntryRepository();
      await repo.add(rent(DateTime(2026, 8, 5)));
      final today = DateTime(2026, 11, 22, 9);

      expect(await createDueRecurring(repo, today), 3); // Sep, Oct, Nov
      final dates = (await repo.all()).map((e) => e.date).toList()..sort();
      expect(dates, [
        DateTime(2026, 8, 5),
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
        DateTime(2026, 11, 5),
      ]);
      final copy = (await repo.all()).firstWhere((e) => e.seriesId != null);
      expect(copy.data.repeat, isNull); // copies don't repeat
      expect(copy.data.subcategory, 'Rent');

      expect(await createDueRecurring(repo, today), 0); // idempotent
    });

    test(
      'nothing before the next date; deleted copy is not recreated',
      () async {
        final repo = InMemoryEntryRepository();
        await repo.add(rent(DateTime(2026, 11, 10)));
        expect(await createDueRecurring(repo, DateTime(2026, 12, 9)), 0);
        expect(await createDueRecurring(repo, DateTime(2026, 12, 10)), 1);

        final copy = (await repo.all()).firstWhere((e) => e.seriesId != null);
        await repo.delete(copy.id);
        expect(await createDueRecurring(repo, DateTime(2026, 12, 20)), 0);
        expect(await createDueRecurring(repo, DateTime(2027, 1, 10)), 1);
      },
    );

    test(
      'turning repeat off or deleting the original stops the series',
      () async {
        final repo = InMemoryEntryRepository();
        final root = await repo.add(rent(DateTime(2026, 9, 1)));
        await repo.update(root, rent(DateTime(2026, 9, 1), repeat: null));
        expect(await createDueRecurring(repo, DateTime(2026, 11, 22)), 0);

        final other = await repo.add(rent(DateTime(2026, 9, 1)));
        await repo.delete(other.id);
        expect(await createDueRecurring(repo, DateTime(2026, 11, 22)), 0);
      },
    );
  });
}
