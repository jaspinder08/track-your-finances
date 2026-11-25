import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tyf_mobile/database/database_helper.dart';
import 'package:tyf_mobile/database/tables/category_budget_table.dart';
import 'package:tyf_mobile/database/tables/entry_table.dart';
import 'package:tyf_mobile/database/tables/user_category_table.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/sync/sync_engine.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

/// The cloud: rows per collection, stamped with an always-rising clock.
class FakeRemote implements RemoteStore {
  FakeRemote(this.uid);
  @override
  String? uid;
  final _byUser = <String, Map<String, Map<String, RemoteRow>>>{};
  Map<String, Map<String, RemoteRow>> get data => _byUser[uid!] ??= {};
  var _clock = DateTime.utc(2026, 1, 1);

  @override
  Future<List<RemoteRow>> pull(String collection, DateTime? since) async => [
    for (final r in (data[collection] ?? {}).values)
      if (since == null || r.serverTime.isAfter(since)) r,
  ];

  @override
  Future<void> push(String collection, List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      _clock = _clock.add(const Duration(minutes: 10));
      (data[collection] ??= {})[r['id'] as String] = RemoteRow(
        Map.of(r),
        _clock,
      );
    }
  }
}

class MapPrefs implements SyncPrefs {
  final _m = <String, Object>{};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  int? getInt(String key) => _m[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => _m[key] = value;
  @override
  Future<void> remove(String key) async => _m.remove(key);
}

/// One phone: its own database, repositories and sync bookkeeping.
class Phone {
  Phone._(this.helper, this.remote)
    : entries = SqliteEntryRepository(helper),
      budgets = SqliteBudgetRepository(helper),
      categories = SqliteCategoryRepository(helper);

  static Future<Phone> create(FakeRemote remote) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false, // each phone gets its own memory database
        onCreate: (db, _) async {
          await db.execute(EntryTable.createTableQuery);
          await db.execute(CategoryBudgetTable.createTableQuery);
          await db.execute(UserCategoryTable.createTableQuery);
        },
      ),
    );
    final helper = DatabaseHelper.withName('phone')..setDatabaseForTesting(db);
    return Phone._(helper, remote);
  }

  final DatabaseHelper helper;
  final FakeRemote remote;
  final SqliteEntryRepository entries;
  final SqliteBudgetRepository budgets;
  final SqliteCategoryRepository categories;
  final prefs = MapPrefs();

  Future<SyncResult> sync() => SyncEngine(helper, remote, prefs).sync();
}

EntryDraft expense(int rupees, {String category = 'Food', DateTime? date}) =>
    EntryDraft(
      type: EntryType.expense,
      amountPaise: rupees * 100,
      date: date ?? DateTime(2026, 11, 20),
      category: category,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeRemote cloud;
  late Phone a, b;
  setUp(() async {
    cloud = FakeRemote('user-1');
    a = await Phone.create(cloud);
    b = await Phone.create(cloud);
  });

  test('data made as a guest uploads, and a new phone gets it all', () async {
    await a.categories.load(); // seeds defaults
    await a.entries.add(expense(250));
    await a.budgets.save(
      const CategoryBudget(category: 'Food', limitPaise: 500000),
    );

    final up = await a.sync();
    expect(up.pushed, greaterThan(2));
    expect(cloud.data['entries'], hasLength(1));

    await b.sync();
    expect((await b.entries.all()).single.data.amountPaise, 25000);
    expect((await b.budgets.all()).single.limitPaise, 500000);
    final cats = await b.categories.load();
    expect(cats.expense.map((c) => c.name), contains('Food'));

    // Nothing left to send, and syncing again changes nothing.
    final again = await a.sync();
    expect(again.pushed, 0);
    expect(again.changed, 0);
  });

  test('edits and deletes reach the other phone', () async {
    final e = await a.entries.add(expense(100));
    await a.sync();
    await b.sync();

    await a.entries.update(e, expense(175));
    await a.sync();
    await b.sync();
    expect((await b.entries.all()).single.data.amountPaise, 17500);

    await b.entries.delete(e.id);
    await b.sync();
    await a.sync();
    expect(await a.entries.all(), isEmpty);
  });

  test('both phones edit the same entry: the later edit wins', () async {
    final e = await a.entries.add(expense(100));
    await a.sync();
    await b.sync();
    final onB = (await b.entries.all()).single;

    await a.entries.update(e, expense(200));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.entries.update(onB, expense(300)); // later

    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.entries.all()).single.data.amountPaise, 30000);
    expect((await b.entries.all()).single.data.amountPaise, 30000);
  });

  test('a budget for the same category on two phones ends up as one', () async {
    await a.budgets.save(
      const CategoryBudget(category: 'Food', limitPaise: 100000),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.budgets.save(
      const CategoryBudget(category: 'Food', limitPaise: 200000),
    );

    await a.sync();
    await b.sync();
    await a.sync();
    for (final p in [a, b]) {
      final all = await p.budgets.all();
      expect(all, hasLength(1));
      expect(all.single.limitPaise, 200000); // the newer one
    }
  });

  test(
    'a new phone keeps the account\'s edited categories, no doubles',
    () async {
      // Phone A: edits Food's emoji and adds a category.
      final set = await a.categories.load();
      await a.categories.saveAll(CategoryKind.expense, [
        for (final c in set.expense)
          c.name == 'Food' ? CategoryOption('Food', '🥗', c.subcategories) : c,
        const CategoryOption('Pets', '🐶'),
      ]);
      await a.sync();

      // Phone B: fresh install seeds the defaults, then signs in.
      await b.categories.load();
      await b.sync();
      final onB = (await b.categories.load()).expense;
      expect(onB.where((c) => c.name == 'Food').single.emoji, '🥗');
      expect(onB.map((c) => c.name), contains('Pets'));
      expect(onB.map((c) => c.name).toSet(), hasLength(onB.length));
    },
  );

  test('recurring copies made on both phones are not doubled', () async {
    final rent = EntryDraft(
      type: EntryType.expense,
      amountPaise: 1500000,
      date: DateTime(2026, 9, 1),
      category: 'Bills',
      repeat: const Repeat(every: 1, unit: RepeatUnit.month),
    );
    await a.entries.add(rent);
    await a.sync();
    await b.sync();

    final now = DateTime(2026, 11, 15);
    await createDueRecurring(a.entries, now); // Oct, Nov
    await createDueRecurring(b.entries, now); // same copies, offline
    await a.sync();
    await b.sync();
    await a.sync();
    for (final p in [a, b]) {
      expect(await p.entries.all(), hasLength(3));
    }
  });

  test('signing in to an account merges this phone\'s guest data', () async {
    await a.entries.add(expense(100));
    await a.sync();

    // Phone B used TYF as a guest, then signs in to the same account.
    await b.entries.add(expense(40, category: 'Travel'));
    await b.sync();
    await a.sync();
    for (final p in [a, b]) {
      expect(await p.entries.all(), hasLength(2));
    }
  });

  test('sign-out removes the data; the next user never gets it', () async {
    await a.entries.add(expense(999)); // user-1's entry
    await a.sync();
    await SyncEngine(a.helper, cloud, a.prefs).clearLocal(); // sign out
    expect(await a.entries.all(), isEmpty);

    // Someone else signs in on the same phone and adds their own entry.
    cloud.uid = 'user-2';
    await a.entries.add(expense(5));
    await a.sync();
    expect((await a.entries.all()).single.data.amountPaise, 500);
    expect(cloud.data['entries'], hasLength(1)); // only theirs

    // user-1 signs back in (after user-2 signs out): all of theirs returns.
    await SyncEngine(a.helper, cloud, a.prefs).clearLocal();
    cloud.uid = 'user-1';
    await a.sync();
    expect((await a.entries.all()).single.data.amountPaise, 99900);
    expect(cloud.data['entries'], hasLength(1));
  });
}
