import 'user_table.dart';
import 'category_table.dart';

/// Defines the schema and queries for the `transactions` table.
///
/// **Why this exists:**
/// This is the core ledger table of TYF.
/// Crucial architectural choices:
/// 1. `amount_cents` is an INTEGER. Floating-point numbers (REAL) introduce rounding
///    errors in financial arithmetic (e.g. $19.99 becomes 19.989999999999998).
/// 2. `category_id` has `ON DELETE RESTRICT` so a category with existing transactions
///    cannot be accidentally hard-deleted.
/// 3. Indexes on `(user_id, transaction_date DESC)` ensure lightning-fast dashboard
///    rendering even with tens of thousands of rows.
class TransactionTable {
  TransactionTable._();

  static const String tableName = 'transactions';

  // Column names
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colCategoryId = 'category_id';
  static const String colAmountCents = 'amount_cents';
  static const String colType = 'type';
  static const String colTransactionDate = 'transaction_date';
  static const String colNote = 'note';
  static const String colPayeePayer = 'payee_payer';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  /// SQL DDL to create the transactions table.
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colUserId TEXT NOT NULL,
      $colCategoryId TEXT NOT NULL,
      $colAmountCents INTEGER NOT NULL CHECK($colAmountCents > 0),
      $colType TEXT NOT NULL CHECK($colType IN ('income', 'expense')),
      $colTransactionDate TEXT NOT NULL,
      $colNote TEXT,
      $colPayeePayer TEXT,
      $colIsDeleted INTEGER NOT NULL DEFAULT 0 CHECK($colIsDeleted IN (0, 1)),
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending_create' CHECK($colSyncStatus IN ('synced', 'pending_create', 'pending_update', 'pending_delete')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      FOREIGN KEY ($colUserId) REFERENCES ${UserTable.tableName}(${UserTable.colId}) ON DELETE CASCADE,
      FOREIGN KEY ($colCategoryId) REFERENCES ${CategoryTable.tableName}(${CategoryTable.colId}) ON DELETE RESTRICT
    );
  ''';

  /// Indexes to accelerate frequent queries
  static const String createIndexUserDate =
      '''
    CREATE INDEX idx_transactions_user_date ON $tableName ($colUserId, $colTransactionDate DESC);
  ''';

  static const String createIndexCategory =
      '''
    CREATE INDEX idx_transactions_category ON $tableName ($colCategoryId);
  ''';

  static const String createIndexSync =
      '''
    CREATE INDEX idx_transactions_sync ON $tableName ($colSyncStatus) WHERE $colSyncStatus != 'synced';
  ''';
}
