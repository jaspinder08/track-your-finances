import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/history/history_screen.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

Entry e(
  String id,
  EntryType t,
  int rupees,
  DateTime d, {
  String? name,
  String? cat,
}) => Entry(
  id: id,
  data: EntryDraft(
    type: t,
    amountPaise: rupees * 100,
    date: d,
    name: name,
    category: cat,
    paymentMethod: 'UPI',
  ),
  createdAt: d,
  updatedAt: d,
);

void main() {
  final all = [
    e(
      '1',
      EntryType.expense,
      450,
      DateTime(2026, 11, 20),
      name: 'Swiggy',
      cat: 'Food',
    ),
    e(
      '2',
      EntryType.expense,
      120,
      DateTime(2026, 11, 20),
      name: 'Auto',
      cat: 'Travel',
    ),
    e(
      '3',
      EntryType.income,
      50000,
      DateTime(2026, 11, 1),
      name: 'Salary',
      cat: 'Salary',
    ),
    e('4', EntryType.goal, 9000, DateTime(2027, 1, 1), name: 'Goa'),
  ];

  test('search by name, category or amount; filter by type and category', () {
    List<String> ids(HistoryFilter f) => [
      for (final g in groupByDay(all, f))
        for (final x in g.$2) x.id,
    ];

    expect(ids(const HistoryFilter()), ['1', '2', '3']); // no goals
    expect(ids(const HistoryFilter(query: 'swig')), ['1']);
    expect(ids(const HistoryFilter(query: 'travel')), ['2']);
    expect(ids(const HistoryFilter(query: '₹450')), ['1']);
    expect(ids(const HistoryFilter(type: EntryType.income)), ['3']);
    expect(ids(const HistoryFilter(category: 'Food')), ['1']);
    expect(groupByDay(all, const HistoryFilter()), hasLength(2)); // 2 days
  });

  test(
    'restore brings a deleted entry back; duplicate copies to a day',
    () async {
      final repo = InMemoryEntryRepository();
      final c = ProviderContainer(
        overrides: [entryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final n = c.read(entriesProvider.notifier);
      await c.read(entriesProvider.future);
      await n.add(
        EntryDraft(
          type: EntryType.expense,
          amountPaise: 2000,
          date: DateTime(2026, 11, 2),
          category: 'Food',
          repeat: const Repeat(every: 1, unit: RepeatUnit.year),
        ),
      );
      final id = c.read(entriesProvider).value!.single.id;

      await n.delete(id);
      expect(c.read(entriesProvider).value, isEmpty);
      await n.restore(id);
      expect(c.read(entriesProvider).value!.single.id, id);

      final original = c.read(entriesProvider).value!.single;
      await n.duplicate(original, day: DateTime(2026, 11, 25));
      final copy = c.read(entriesProvider).value!.firstWhere((x) => x.id != id);
      expect(copy.date, DateTime(2026, 11, 25));
      expect(copy.amountPaise, 2000);
      expect(copy.data.repeat, isNull); // copy never starts a new series
    },
  );

  testWidgets('swipe left deletes, Undo brings it back', (tester) async {
    final repo = InMemoryEntryRepository();
    await repo.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 45000,
        date: DateTime.now(),
        name: 'Swiggy',
        category: 'Food',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(repo),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Swiggy'), findsOneWidget);

    await tester.drag(find.text('Swiggy'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swiggy'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Swiggy'), findsOneWidget);
  });
}
