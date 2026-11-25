import 'user_table.dart';
import 'category_table.dart';

/// Defines the schema and queries for the `budgets` table.
///
/// **Why this exists:**
/// Users can set monthly expense targets per category.
/// - `UNIQUE(user_id, category_id, month, year)` ensures a user cannot set two conflicting
///   budgets for the same category in the same month.
/// - `limit_cents` is an INTEGER to preserve monetary precision.
class BudgetTable {
  BudgetTable._();

  static const String tableName = 'budgets';

  // Column names
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colCategoryId = 'category_id';
  static const String colLimitCents = 'limit_cents';
  static const String colMonth = 'month';
  static const String colYear = 'year';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  /// SQL DDL to create the budgets table.
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colUserId TEXT NOT NULL,
      $colCategoryId TEXT NOT NULL,
      $colLimitCents INTEGER NOT NULL CHECK($colLimitCents > 0),
      $colMonth INTEGER NOT NULL CHECK($colMonth BETWEEN 1 AND 12),
      $colYear INTEGER NOT NULL CHECK($colYear >= 2020),
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      FOREIGN KEY ($colUserId) REFERENCES ${UserTable.tableName}(${UserTable.colId}) ON DELETE CASCADE,
      FOREIGN KEY ($colCategoryId) REFERENCES ${CategoryTable.tableName}(${CategoryTable.colId}) ON DELETE CASCADE,
      UNIQUE($colUserId, $colCategoryId, $colMonth, $colYear)
    );
  ''';

  /// Composite index for fast budget retrieval per period
  static const String createIndexUserPeriod =
      '''
    CREATE INDEX idx_budgets_user_period ON $tableName ($colUserId, $colYear, $colMonth);
  ''';
}
