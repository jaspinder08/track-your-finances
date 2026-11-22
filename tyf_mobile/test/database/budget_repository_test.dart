import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tyf_mobile/database/database.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late SqliteBudgetRepository repo;

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(CategoryBudgetTable.createTableQuery),
      ),
    );
    helper = DatabaseHelper.withName('budget_test.db')
      ..setDatabaseForTesting(db);
    repo = SqliteBudgetRepository(helper);
  });

  tearDown(() => helper.close());

  test('save creates, then replaces the same category', () async {
    await repo.save(const CategoryBudget(category: 'Food', limitPaise: 500000));
    await repo.save(
      const CategoryBudget(
        category: 'Food',
        limitPaise: 800000,
        alertAt80: false,
      ),
    );
    final all = await repo.all();
    expect(all, hasLength(1));
    expect(all.single.limitPaise, 800000);
    expect(all.single.alertAt80, isFalse);
  });

  test('remove hides it and saving again brings it back', () async {
    await repo.save(const CategoryBudget(category: 'Travel', limitPaise: 1000));
    await repo.remove('Travel');
    expect(await repo.all(), isEmpty);
    await repo.save(const CategoryBudget(category: 'Travel', limitPaise: 2000));
    expect((await repo.all()).single.limitPaise, 2000);
  });
}
