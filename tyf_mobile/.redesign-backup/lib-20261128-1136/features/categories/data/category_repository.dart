import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../database/database_helper.dart';
import '../../../database/tables/user_category_table.dart';
import '../../budgets/data/budget_repository.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';

/// Expense or income list.
enum CategoryKind {
  expense('Expense'),
  income('Income');

  const CategoryKind(this.label);
  final String label;

  EntryType get entryType =>
      this == expense ? EntryType.expense : EntryType.income;
}

/// The user's categories, both kinds, in display order.
@immutable
class CategorySet {
  const CategorySet({required this.expense, required this.income});
  final List<CategoryOption> expense;
  final List<CategoryOption> income;

  static const defaults = CategorySet(
    expense: expenseCategories,
    income: incomeCategories,
  );

  List<CategoryOption> of(CategoryKind k) =>
      k == CategoryKind.expense ? expense : income;

  /// Emoji for a category name (expense first), or null if unknown.
  String? emojiFor(String? name) =>
      [...expense, ...income].where((c) => c.name == name).firstOrNull?.emoji;
}

abstract class CategoryRepository {
  /// Loads the lists, seeding the defaults the first time.
  Future<CategorySet> load();

  /// Saves one kind's whole list (order = position).
  Future<void> saveAll(CategoryKind kind, List<CategoryOption> list);
}

class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository(this._helper);
  final DatabaseHelper _helper;
  static const _uuid = Uuid();
  static const _t = UserCategoryTable.tableName;

  @override
  Future<CategorySet> load() async {
    final db = await _helper.database;
    final count =
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $_t')).first['n'] as int;
    if (count == 0) {
      await _saveAll(CategoryKind.expense, expenseCategories, seed: true);
      await _saveAll(CategoryKind.income, incomeCategories, seed: true);
    }
    Future<List<CategoryOption>> read(CategoryKind k) async {
      final rows = await db.query(
        _t,
        where:
            '${UserCategoryTable.colKind} = ? AND ${UserCategoryTable.colIsDeleted} = 0',
        whereArgs: [k.name],
        orderBy: UserCategoryTable.colSortOrder,
      );
      return [
        for (final r in rows)
          CategoryOption(
            r[UserCategoryTable.colName] as String,
            r[UserCategoryTable.colEmoji] as String,
            (jsonDecode(r[UserCategoryTable.colSubcategories] as String)
                    as List)
                .cast<String>(),
          ),
      ];
    }

    return CategorySet(
      expense: await read(CategoryKind.expense),
      income: await read(CategoryKind.income),
    );
  }

  /// Upserts by (kind, name) and soft-deletes names no longer present.
  @override
  Future<void> saveAll(CategoryKind kind, List<CategoryOption> list) =>
      _saveAll(kind, list);

  /// [seed]: the first-launch defaults. They get fixed IDs and the oldest
  /// possible time, so on a new phone the account's own (edited) copies
  /// win when synced, and two phones' defaults are the same rows.
  Future<void> _saveAll(
    CategoryKind kind,
    List<CategoryOption> list, {
    bool seed = false,
  }) async {
    final db = await _helper.database;
    final now = seed
        ? DateTime.utc(1970).toIso8601String()
        : DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final existing = {
        for (final r in await txn.query(
          _t,
          where: '${UserCategoryTable.colKind} = ?',
          whereArgs: [kind.name],
        ))
          r[UserCategoryTable.colName] as String: r,
      };
      for (var i = 0; i < list.length; i++) {
        final c = list[i];
        final values = {
          UserCategoryTable.colEmoji: c.emoji,
          UserCategoryTable.colSubcategories: jsonEncode(c.subcategories),
          UserCategoryTable.colSortOrder: i,
          UserCategoryTable.colIsDeleted: 0,
          UserCategoryTable.colUpdatedAt: now,
        };
        final row = existing.remove(c.name);
        if (row == null) {
          await txn.insert(_t, {
            ...values,
            UserCategoryTable.colId: seed
                ? 'default-${kind.name}-${c.name}'
                : _uuid.v4(),
            UserCategoryTable.colKind: kind.name,
            UserCategoryTable.colName: c.name,
            UserCategoryTable.colCreatedAt: now,
          });
        } else {
          await txn.update(
            _t,
            {
              ...values,
              UserCategoryTable.colSyncStatus:
                  row[UserCategoryTable.colSyncStatus] == 'pending_create'
                  ? 'pending_create'
                  : 'pending_update',
            },
            where: '${UserCategoryTable.colId} = ?',
            whereArgs: [row[UserCategoryTable.colId]],
          );
        }
      }
      for (final row in existing.values) {
        if (row[UserCategoryTable.colIsDeleted] == 1) continue;
        await txn.update(
          _t,
          {
            UserCategoryTable.colIsDeleted: 1,
            UserCategoryTable.colSyncStatus: 'pending_delete',
            UserCategoryTable.colUpdatedAt: now,
          },
          where: '${UserCategoryTable.colId} = ?',
          whereArgs: [row[UserCategoryTable.colId]],
        );
      }
    });
  }
}

class InMemoryCategoryRepository implements CategoryRepository {
  var _set = CategorySet.defaults;
  @override
  Future<CategorySet> load() async => _set;
  @override
  Future<void> saveAll(CategoryKind kind, List<CategoryOption> list) async {
    _set = kind == CategoryKind.expense
        ? CategorySet(expense: List.of(list), income: _set.income)
        : CategorySet(expense: _set.expense, income: List.of(list));
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => SqliteCategoryRepository(DatabaseHelper.instance),
);

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, CategorySet>(
      CategoriesNotifier.new,
    );

/// The user's lists, or the defaults while loading (or if loading fails).
final categorySetProvider = Provider<CategorySet>(
  (ref) => ref.watch(categoriesProvider).value ?? CategorySet.defaults,
);

class CategoriesNotifier extends AsyncNotifier<CategorySet> {
  CategoryRepository get _repo => ref.read(categoryRepositoryProvider);

  @override
  Future<CategorySet> build() => ref.watch(categoryRepositoryProvider).load();

  CategorySet get _now => state.value ?? CategorySet.defaults;

  Future<void> _save(CategoryKind k, List<CategoryOption> list) async {
    await _repo.saveAll(k, list);
    state = AsyncData(await _repo.load());
  }

  /// Name already used in that list (case-insensitive)?
  bool nameTaken(CategoryKind k, String name, {String? except}) => _now
      .of(k)
      .any(
        (c) =>
            c.name.toLowerCase() == name.toLowerCase() &&
            c.name.toLowerCase() != except?.toLowerCase(),
      );

  Future<void> add(CategoryKind k, CategoryOption c) =>
      _save(k, [..._now.of(k), c]);

  /// Replaces [oldName] with [c]. A rename also renames it on existing
  /// entries (and budgets for expense categories).
  Future<void> replace(CategoryKind k, String oldName, CategoryOption c) async {
    await _save(k, [for (final x in _now.of(k)) x.name == oldName ? c : x]);
    if (c.name != oldName) {
      await ref
          .read(entryRepositoryProvider)
          .renameCategory(k.entryType, oldName, c.name);
      ref.invalidate(entriesProvider);
      if (k == CategoryKind.expense) {
        await ref.read(budgetRepositoryProvider).rename(oldName, c.name);
        ref.invalidate(budgetsProvider);
      }
    }
  }

  /// Removes it from the list. Past entries keep the name.
  Future<void> remove(CategoryKind k, String name) =>
      _save(k, [..._now.of(k).where((c) => c.name != name)]);

  Future<void> reorder(CategoryKind k, int from, int to) {
    final list = [..._now.of(k)];
    final c = list.removeAt(from);
    list.insert(to > from ? to - 1 : to, c);
    return _save(k, list);
  }

  Future<void> resetDefaults(CategoryKind k) => _save(
    k,
    k == CategoryKind.expense ? expenseCategories : incomeCategories,
  );
}
