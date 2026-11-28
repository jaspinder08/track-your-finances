import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../database/database_helper.dart';
import '../../../database/tables/category_budget_table.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';

/// A monthly spending limit for one expense category.
@immutable
class CategoryBudget {
  const CategoryBudget({
    required this.category,
    required this.limitPaise,
    this.alertAt80 = true,
  });
  final String category;
  final int limitPaise;
  final bool alertAt80;
}

abstract class BudgetRepository {
  Future<List<CategoryBudget>> all();

  /// Creates or replaces the budget for that category.
  Future<void> save(CategoryBudget budget);
  Future<void> remove(String category);
  Future<void> rename(String from, String to);
}

class SqliteBudgetRepository implements BudgetRepository {
  SqliteBudgetRepository(this._helper);
  final DatabaseHelper _helper;
  static const _uuid = Uuid();
  static const _t = CategoryBudgetTable.tableName;

  @override
  Future<List<CategoryBudget>> all() async {
    final db = await _helper.database;
    final rows = await db.query(
      _t,
      where: '${CategoryBudgetTable.colIsDeleted} = 0',
    );
    return [
      for (final r in rows)
        CategoryBudget(
          category: r[CategoryBudgetTable.colCategory] as String,
          limitPaise: r[CategoryBudgetTable.colLimitPaise] as int,
          alertAt80: r[CategoryBudgetTable.colAlert] == 1,
        ),
    ];
  }

  @override
  Future<void> save(CategoryBudget b) async {
    final db = await _helper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final values = {
      CategoryBudgetTable.colLimitPaise: b.limitPaise,
      CategoryBudgetTable.colAlert: b.alertAt80 ? 1 : 0,
      CategoryBudgetTable.colIsDeleted: 0,
      CategoryBudgetTable.colUpdatedAt: now,
    };
    final n = await db.update(
      _t,
      {...values, CategoryBudgetTable.colSyncStatus: 'pending_update'},
      where: '${CategoryBudgetTable.colCategory} = ?',
      whereArgs: [b.category],
    );
    if (n == 0) {
      await db.insert(_t, {
        ...values,
        CategoryBudgetTable.colId: _uuid.v4(),
        CategoryBudgetTable.colCategory: b.category,
        CategoryBudgetTable.colCreatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }
  }

  @override
  Future<void> rename(String from, String to) async {
    final db = await _helper.database;
    await db.update(
      _t,
      {
        CategoryBudgetTable.colCategory: to,
        CategoryBudgetTable.colSyncStatus: 'pending_update',
        CategoryBudgetTable.colUpdatedAt: DateTime.now()
            .toUtc()
            .toIso8601String(),
      },
      where: '${CategoryBudgetTable.colCategory} = ?',
      whereArgs: [from],
    );
  }

  @override
  Future<void> remove(String category) async {
    final db = await _helper.database;
    await db.update(
      _t,
      {
        CategoryBudgetTable.colIsDeleted: 1,
        CategoryBudgetTable.colSyncStatus: 'pending_delete',
        CategoryBudgetTable.colUpdatedAt: DateTime.now()
            .toUtc()
            .toIso8601String(),
      },
      where: '${CategoryBudgetTable.colCategory} = ?',
      whereArgs: [category],
    );
  }
}

class InMemoryBudgetRepository implements BudgetRepository {
  final _items = <String, CategoryBudget>{};
  @override
  Future<List<CategoryBudget>> all() async => _items.values.toList();
  @override
  Future<void> save(CategoryBudget b) async => _items[b.category] = b;
  @override
  Future<void> remove(String category) async => _items.remove(category);
  @override
  Future<void> rename(String from, String to) async {
    final b = _items.remove(from);
    if (b != null) {
      _items[to] = CategoryBudget(
        category: to,
        limitPaise: b.limitPaise,
        alertAt80: b.alertAt80,
      );
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => SqliteBudgetRepository(DatabaseHelper.instance),
);

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<CategoryBudget>>(
      BudgetsNotifier.new,
    );

class BudgetsNotifier extends AsyncNotifier<List<CategoryBudget>> {
  BudgetRepository get _repo => ref.read(budgetRepositoryProvider);

  @override
  Future<List<CategoryBudget>> build() =>
      ref.watch(budgetRepositoryProvider).all();

  Future<void> save(CategoryBudget b) async {
    await _repo.save(b);
    state = AsyncData(await _repo.all());
  }

  Future<void> remove(String category) async {
    await _repo.remove(category);
    state = AsyncData(await _repo.all());
  }
}

/// This month's expense total per category name.
final monthSpendProvider = Provider<Map<String, int>>((ref) {
  final now = DateTime.now();
  return _spendIn(ref.watch(entriesProvider).value, now.year, now.month);
});

/// Last month's expense total per category (for budget suggestions).
final lastMonthSpendProvider = Provider<Map<String, int>>((ref) {
  final now = DateTime.now();
  final m = DateTime(now.year, now.month - 1);
  return _spendIn(ref.watch(entriesProvider).value, m.year, m.month);
});

Map<String, int> _spendIn(List<Entry>? entries, int year, int month) {
  final out = <String, int>{};
  for (final e in entries ?? const <Entry>[]) {
    if (e.type != EntryType.expense) continue;
    if (e.date.year != year || e.date.month != month) continue;
    final c = e.data.category ?? 'Other';
    out[c] = (out[c] ?? 0) + e.amountPaise;
  }
  return out;
}

/// One budget row for the UI: limit, spent so far, and its category.
@immutable
class BudgetProgress {
  const BudgetProgress(this.budget, this.spentPaise, this.option);
  final CategoryBudget budget;
  final int spentPaise;
  final CategoryOption? option;

  int get leftPaise => budget.limitPaise - spentPaise;
  double get ratio => spentPaise / budget.limitPaise;
  bool get isOver => spentPaise > budget.limitPaise;
  bool get isNear => !isOver && ratio >= 0.8;
}

/// Budgets with this month's progress, most-used first.
final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final spend = ref.watch(monthSpendProvider);
  final cats = ref.watch(categorySetProvider).expense;
  final list = [
    for (final b in ref.watch(budgetsProvider).value ?? const [])
      BudgetProgress(
        b,
        spend[b.category] ?? 0,
        cats.where((c) => c.name == b.category).firstOrNull,
      ),
  ]..sort((a, b) => b.ratio.compareTo(a.ratio));
  return list;
});
