import 'package:sqflite/sqflite.dart';
import '../models/budget_model.dart';
import '../tables/budget_table.dart';

/// Data Access Object for monthly budget allocation persistence.
class BudgetDao {
  final Database db;

  const BudgetDao(this.db);

  DatabaseExecutor _executor(DatabaseExecutor? executor) => executor ?? db;

  /// Inserts or replaces a budget for a category in a given month.
  Future<void> upsertBudget(
    BudgetModel budget, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.insert(
      BudgetTable.tableName,
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a budget for a specific category in a month and year.
  Future<BudgetModel?> getBudget({
    required String userId,
    required String categoryId,
    required int month,
    required int year,
  }) async {
    final results = await db.query(
      BudgetTable.tableName,
      where:
          '${BudgetTable.colUserId} = ? AND ${BudgetTable.colCategoryId} = ? AND ${BudgetTable.colMonth} = ? AND ${BudgetTable.colYear} = ? AND ${BudgetTable.colIsDeleted} = 0',
      whereArgs: [userId, categoryId, month, year],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return BudgetModel.fromMap(results.first);
  }

  /// Retrieves all active budgets for a given calendar month.
  Future<List<BudgetModel>> getBudgetsForMonth({
    required String userId,
    required int month,
    required int year,
  }) async {
    final results = await db.query(
      BudgetTable.tableName,
      where:
          '${BudgetTable.colUserId} = ? AND ${BudgetTable.colMonth} = ? AND ${BudgetTable.colYear} = ? AND ${BudgetTable.colIsDeleted} = 0',
      whereArgs: [userId, month, year],
    );

    return results.map(BudgetModel.fromMap).toList();
  }

  /// Soft deletes a budget.
  Future<void> softDeleteBudget(
    String budgetId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      BudgetTable.tableName,
      {
        BudgetTable.colIsDeleted: 1,
        BudgetTable.colSyncStatus: 'pending_delete',
        BudgetTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${BudgetTable.colId} = ?',
      whereArgs: [budgetId],
    );
  }

  /// Updates synchronization status.
  Future<void> updateSyncStatus(
    String budgetId,
    String status, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      BudgetTable.tableName,
      {
        BudgetTable.colSyncStatus: status,
        BudgetTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${BudgetTable.colId} = ?',
      whereArgs: [budgetId],
    );
  }
}
