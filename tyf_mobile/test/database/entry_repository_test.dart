import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tyf_mobile/database/database.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late SqliteEntryRepository repo;

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(EntryTable.createTableQuery),
      ),
    );
    helper = DatabaseHelper.withName('test.db')..setDatabaseForTesting(db);
    repo = SqliteEntryRepository(helper);
  });

  tearDown(() => helper.close());

  test('saves every field and reads it back', () async {
    final saved = await repo.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 99950,
        date: DateTime(2026, 11, 21),
        name: 'Rent',
        description: 'November',
        category: 'Home',
        subcategory: 'Rent',
        paymentMethod: 'UPI',
        repeat: const Repeat(every: 1, unit: RepeatUnit.month),
      ),
    );
    final all = await repo.all();
    expect(all, hasLength(1));
    final e = all.single;
    expect(e.id, saved.id);
    expect(e.type, EntryType.expense);
    expect(e.amountPaise, 99950);
    expect(e.date, DateTime(2026, 11, 21));
    expect(e.data.subcategory, 'Rent');
    expect(e.data.paymentMethod, 'UPI');
    expect(e.data.repeat?.unit, RepeatUnit.month);
    expect(e.balanceEffect, -99950);
  });

  test('transfer and goal round-trip; delete hides the entry', () async {
    final t = await repo.add(
      EntryDraft(
        type: EntryType.transfer,
        amountPaise: 500000,
        date: DateTime(2026, 11, 1),
        fromAccount: 'Bank account',
        toAccount: 'Savings account',
      ),
    );
    await repo.add(
      EntryDraft(
        type: EntryType.goal,
        amountPaise: 8000000,
        date: DateTime(2027, 5, 1),
        name: 'Laptop',
        savedSoFarPaise: 1000000,
      ),
    );
    var all = await repo.all();
    expect(all.first.data.name, 'Laptop'); // newest date first
    expect(all.last.title, 'Bank account → Savings account');
    expect(all.first.data.savedSoFarPaise, 1000000);

    await repo.delete(t.id);
    all = await repo.all();
    expect(all.map((e) => e.type), [EntryType.goal]);
  });
}
