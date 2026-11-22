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

  test('update changes fields and marks synced rows pending_update', () async {
    final e = await repo.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 10000,
        date: DateTime(2026, 11, 20),
        name: 'Tea',
        category: 'Food',
      ),
    );
    Future<String> status() async =>
        (await (await helper.database).query(
              EntryTable.tableName,
            )).single[EntryTable.colSyncStatus]
            as String;

    await repo.update(
      e,
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 12550,
        date: DateTime(2026, 11, 21),
        name: 'Tea & snacks',
        category: 'Food',
        subcategory: 'Snacks',
      ),
    );
    var saved = (await repo.all()).single;
    expect(saved.id, e.id);
    expect(saved.amountPaise, 12550);
    expect(saved.date, DateTime(2026, 11, 21));
    expect(saved.data.subcategory, 'Snacks');
    expect(await status(), 'pending_create'); // never synced yet

    await (await helper.database).update(EntryTable.tableName, {
      EntryTable.colSyncStatus: 'synced',
    });
    await repo.update(
      saved,
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 13000,
        date: saved.date,
        category: 'Food',
      ),
    );
    saved = (await repo.all()).single;
    expect(saved.data.name, isNull);
    expect(await status(), 'pending_update');
  });

  test('series_id round-trips through SQLite', () async {
    final root = await repo.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 100,
        date: DateTime(2026, 10, 1),
        repeat: const Repeat(every: 1, unit: RepeatUnit.month),
      ),
    );
    expect(await createDueRecurring(repo, DateTime(2026, 11, 22)), 1);
    final copy = (await repo.all()).firstWhere((e) => e.id != root.id);
    expect(copy.seriesId, root.id);
    expect(copy.date, DateTime(2026, 11, 1));
  });
}
