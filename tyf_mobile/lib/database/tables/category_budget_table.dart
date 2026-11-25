/// Defines the `category_budgets` table: one monthly limit per expense
/// category, keyed by category name (like `entries`, so it works offline
/// before sign-in). The older `budgets` table needs user/category rows.
class CategoryBudgetTable {
  CategoryBudgetTable._();

  static const String tableName = 'category_budgets';

  static const String colId = 'id';
  static const String colCategory = 'category';
  static const String colLimitPaise = 'limit_paise';
  static const String colAlert = 'alert_at_80';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colCategory TEXT NOT NULL UNIQUE,
      $colLimitPaise INTEGER NOT NULL CHECK($colLimitPaise > 0),
      $colAlert INTEGER NOT NULL DEFAULT 1 CHECK($colAlert IN (0, 1)),
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL
    );
  ''';
}
