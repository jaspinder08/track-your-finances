/// Defines the `user_categories` table: the user's own expense and income
/// categories with emoji, subcategories (JSON array) and display order.
/// Seeded with TYF's defaults on first launch.
class UserCategoryTable {
  UserCategoryTable._();

  static const String tableName = 'user_categories';

  static const String colId = 'id';
  static const String colKind = 'kind';
  static const String colName = 'name';
  static const String colEmoji = 'emoji';
  static const String colSubcategories = 'subcategories';
  static const String colSortOrder = 'sort_order';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colKind TEXT NOT NULL CHECK($colKind IN ('expense', 'income')),
      $colName TEXT NOT NULL,
      $colEmoji TEXT NOT NULL,
      $colSubcategories TEXT NOT NULL DEFAULT '[]',
      $colSortOrder INTEGER NOT NULL DEFAULT 0,
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL
    );
  ''';
}
