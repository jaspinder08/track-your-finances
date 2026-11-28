/// Defines the `entries` table: everything the add sheet collects
/// (income, expense, transfer, goal) in one row.
///
/// **Why a separate table from `transactions`:** `transactions` only
/// allows income/expense and needs user and category rows, which don't
/// exist until sign-in (phase 4). `entries` stores category names as
/// text so the app works offline from the first launch.
///
/// Money is INTEGER paise; dates are local `yyyy-MM-dd` so a day never
/// shifts across time zones. Sync columns match the other tables.
class EntryTable {
  EntryTable._();

  static const String tableName = 'entries';

  static const String colId = 'id';
  static const String colType = 'type';
  static const String colAmountPaise = 'amount_paise';
  static const String colEntryDate = 'entry_date';
  static const String colName = 'name';
  static const String colDescription = 'description';
  static const String colCategory = 'category';
  static const String colSubcategory = 'subcategory';
  static const String colPaymentMethod = 'payment_method';
  static const String colFromAccount = 'from_account';
  static const String colToAccount = 'to_account';
  static const String colSavedSoFarPaise = 'saved_so_far_paise';
  static const String colRepeatEvery = 'repeat_every';
  static const String colRepeatUnit = 'repeat_unit';
  static const String colSeriesId = 'series_id';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colType TEXT NOT NULL CHECK($colType IN ('income', 'expense', 'transfer', 'goal')),
      $colAmountPaise INTEGER NOT NULL CHECK($colAmountPaise > 0),
      $colEntryDate TEXT NOT NULL,
      $colName TEXT,
      $colDescription TEXT,
      $colCategory TEXT,
      $colSubcategory TEXT,
      $colPaymentMethod TEXT,
      $colFromAccount TEXT,
      $colToAccount TEXT,
      $colSavedSoFarPaise INTEGER,
      $colRepeatEvery INTEGER,
      $colRepeatUnit TEXT,
      $colSeriesId TEXT,
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL
    );
  ''';

  /// v3: links auto-created copies to their recurring original.
  static const String addSeriesIdColumn =
      'ALTER TABLE $tableName ADD COLUMN $colSeriesId TEXT;';

  static const String createIndexDate =
      '''
    CREATE INDEX idx_entries_date ON $tableName ($colEntryDate DESC);
  ''';
}
