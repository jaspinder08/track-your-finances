/// Defines the schema, table name, and column names for the `users` table.
///
/// **Why this exists:**
/// Hardcoding SQL strings like `SELECT * FROM users WHERE id = ...` throughout
/// the application causes silent typo bugs (e.g. typing `user_id` instead of `id`).
/// By centralizing column identifiers as static constants, we gain compile-time
/// safety and clean refactoring support.
class UserTable {
  UserTable._();

  static const String tableName = 'users';

  // Column names
  static const String colId = 'id';
  static const String colEmail = 'email';
  static const String colDisplayName = 'display_name';
  static const String colCurrencyCode = 'currency_code';
  static const String colRole = 'role';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colLastSyncedAt = 'last_synced_at';

  /// SQL DDL statement to construct the table with constraints.
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY NOT NULL,
      $colEmail TEXT NOT NULL UNIQUE,
      $colDisplayName TEXT,
      $colCurrencyCode TEXT NOT NULL DEFAULT 'USD',
      $colRole TEXT NOT NULL DEFAULT 'user' CHECK($colRole IN ('user', 'admin')),
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      $colLastSyncedAt TEXT
    );
  ''';
}
