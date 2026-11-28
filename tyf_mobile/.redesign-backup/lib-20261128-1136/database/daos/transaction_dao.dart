import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';
import '../tables/transaction_table.dart';

/// Data Access Object for local financial transactions.
class TransactionDao {
  final Database db;

  const TransactionDao(this.db);

  DatabaseExecutor _executor(DatabaseExecutor? executor) => executor ?? db;

  /// Inserts a transaction into SQLite.
  Future<void> insertTransaction(
    TransactionModel transaction, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.insert(
      TransactionTable.tableName,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing transaction.
  Future<void> updateTransaction(
    TransactionModel transaction, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      TransactionTable.tableName,
      transaction.toMap(),
      where: '${TransactionTable.colId} = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Soft deletes a transaction.
  Future<void> softDeleteTransaction(
    String transactionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      TransactionTable.tableName,
      {
        TransactionTable.colIsDeleted: 1,
        TransactionTable.colSyncStatus: 'pending_delete',
        TransactionTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${TransactionTable.colId} = ?',
      whereArgs: [transactionId],
    );
  }

  /// Retrieves a transaction by ID.
  Future<TransactionModel?> getTransactionById(
    String transactionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    final results = await exec.query(
      TransactionTable.tableName,
      where: '${TransactionTable.colId} = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return TransactionModel.fromMap(results.first);
  }

  /// Queries transactions with filtering, pagination, and sorting.
  Future<List<TransactionModel>> getTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? type,
    bool includeDeleted = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final whereClauses = <String>['${TransactionTable.colUserId} = ?'];
    final whereArgs = <dynamic>[userId];

    if (!includeDeleted) {
      whereClauses.add('${TransactionTable.colIsDeleted} = 0');
    }

    if (startDate != null) {
      whereClauses.add('${TransactionTable.colTransactionDate} >= ?');
      whereArgs.add(startDate.toUtc().toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('${TransactionTable.colTransactionDate} <= ?');
      whereArgs.add(endDate.toUtc().toIso8601String());
    }

    if (categoryId != null) {
      whereClauses.add('${TransactionTable.colCategoryId} = ?');
      whereArgs.add(categoryId);
    }

    if (type != null) {
      whereClauses.add('${TransactionTable.colType} = ?');
      whereArgs.add(type);
    }

    final results = await db.query(
      TransactionTable.tableName,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: '${TransactionTable.colTransactionDate} DESC',
      limit: limit,
      offset: offset,
    );

    return results.map(TransactionModel.fromMap).toList();
  }

  /// Calculates total amount in cents for a given type ('income' or 'expense') in a period.
  Future<int> getTotalAmountCents({
    required String userId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(${TransactionTable.colAmountCents}), 0) AS total
      FROM ${TransactionTable.tableName}
      WHERE ${TransactionTable.colUserId} = ?
        AND ${TransactionTable.colType} = ?
        AND ${TransactionTable.colIsDeleted} = 0
        AND ${TransactionTable.colTransactionDate} >= ?
        AND ${TransactionTable.colTransactionDate} <= ?
      ''',
      [
        userId,
        type,
        startDate.toUtc().toIso8601String(),
        endDate.toUtc().toIso8601String(),
      ],
    );

    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total'] as num).toInt();
  }

  /// Calculates total expenses grouped by category ID for monthly budget tracking and charts.
  Future<Map<String, int>> getExpensesByCategory({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await db.rawQuery(
      '''
      SELECT ${TransactionTable.colCategoryId}, SUM(${TransactionTable.colAmountCents}) AS total
      FROM ${TransactionTable.tableName}
      WHERE ${TransactionTable.colUserId} = ?
        AND ${TransactionTable.colType} = 'expense'
        AND ${TransactionTable.colIsDeleted} = 0
        AND ${TransactionTable.colTransactionDate} >= ?
        AND ${TransactionTable.colTransactionDate} <= ?
      GROUP BY ${TransactionTable.colCategoryId}
      ''',
      [
        userId,
        startDate.toUtc().toIso8601String(),
        endDate.toUtc().toIso8601String(),
      ],
    );

    final map = <String, int>{};
    for (final row in results) {
      final catId = row[TransactionTable.colCategoryId] as String;
      final total = (row['total'] as num).toInt();
      map[catId] = total;
    }
    return map;
  }

  /// Updates the sync_status column of a transaction.
  Future<void> updateSyncStatus(
    String transactionId,
    String status, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      TransactionTable.tableName,
      {
        TransactionTable.colSyncStatus: status,
        TransactionTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${TransactionTable.colId} = ?',
      whereArgs: [transactionId],
    );
  }
}
