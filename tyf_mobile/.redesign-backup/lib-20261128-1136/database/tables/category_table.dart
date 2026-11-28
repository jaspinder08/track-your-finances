import 'user_table.dart';

/// Defines the schema and queries for the `categories` table.
///
/// **Why this exists:**
/// Categories categorize both Income and Expense transactions. We include:
/// 1. `is_default` (integer 0/1) for system-seeded categories (Groceries, Salary, etc.)
/// 2. `is_deleted` for soft-deletion (critical for offline-first sync).
/// 3. `sync_status` to track replication state with Cloud Firestore.
class CategoryTable {
  CategoryTable._();

  static const String tableName = 'categories';

  // Column names
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colIconKey = 'icon_key';
  static const String colColorHex = 'color_hex';
  static const String colIsDefault = 'is_default';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  /// SQL DDL to create the categories table with strict foreign keys and check constraints.
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colUserId TEXT NOT NULL,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL CHECK($colType IN ('income', 'expense')),
      $colIconKey TEXT NOT NULL,
      $colColorHex TEXT NOT NULL,
      $colIsDefault INTEGER NOT NULL DEFAULT 0 CHECK($colIsDefault IN (0, 1)),
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      FOREIGN KEY ($colUserId) REFERENCES ${UserTable.tableName}(${UserTable.colId}) ON DELETE CASCADE
    );
  ''';

  /// Composite index for fast category lookups per user excluding soft-deleted items.
  static const String createIndexUserDeleted =
      '''
    CREATE INDEX idx_categories_user_deleted ON $tableName ($colUserId, $colIsDeleted);
  ''';
}
