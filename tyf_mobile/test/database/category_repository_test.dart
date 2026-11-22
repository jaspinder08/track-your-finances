import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tyf_mobile/database/database.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late SqliteCategoryRepository repo;

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(UserCategoryTable.createTableQuery),
      ),
    );
    helper = DatabaseHelper.withName('cat_test.db')..setDatabaseForTesting(db);
    repo = SqliteCategoryRepository(helper);
  });

  tearDown(() => helper.close());

  test('first load seeds the defaults with subcategories', () async {
    final s = await repo.load();
    expect(s.expense.map((c) => c.name), expenseCategories.map((c) => c.name));
    expect(s.expense.first.subcategories, contains('Rent'));
    expect(s.income, hasLength(incomeCategories.length));
  });

  test('saveAll keeps order, edits and soft-deletes removed', () async {
    await repo.load();
    await repo.saveAll(CategoryKind.expense, const [
      CategoryOption('Pets', '🐶', ['Vet', 'Food']),
      CategoryOption('Food', '🍕'),
    ]);
    final s = await repo.load();
    expect(s.expense.map((c) => c.name), ['Pets', 'Food']);
    expect(s.expense.first.subcategories, ['Vet', 'Food']);
    expect(s.expense.last.emoji, '🍕');
    // Not re-seeded: rows exist (deleted ones count).
    expect((await repo.load()).expense, hasLength(2));
  });
}
