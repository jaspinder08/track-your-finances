/// Defines the schema and queries for the `sync_queue` table.
///
/// **Why this exists:**
/// This implements the Transactional Outbox Pattern for the offline-first sync engine.
/// When any entity is created, modified, or deleted locally, an entry is written
/// atomically to this table.
/// The background SyncEngine reads from this table in ascending order (`id ASC`),
/// pushes the changes to Firebase, and then deletes the queue item upon server confirmation.
class SyncQueueTable {
  SyncQueueTable._();

  static const String tableName = 'sync_queue';

  // Column names
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colEntityType = 'entity_type';
  static const String colEntityId = 'entity_id';
  static const String colOperation = 'operation';
  static const String colPayloadJson = 'payload_json';
  static const String colRetryCount = 'retry_count';
  static const String colLastError = 'last_error';
  static const String colCreatedAt = 'created_at';

  /// SQL DDL to create the sync_queue table.
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colUserId TEXT NOT NULL,
      $colEntityType TEXT NOT NULL CHECK($colEntityType IN ('transaction', 'category', 'budget', 'user')),
      $colEntityId TEXT NOT NULL,
      $colOperation TEXT NOT NULL CHECK($colOperation IN ('CREATE', 'UPDATE', 'DELETE')),
      $colPayloadJson TEXT NOT NULL,
      $colRetryCount INTEGER NOT NULL DEFAULT 0,
      $colLastError TEXT,
      $colCreatedAt TEXT NOT NULL
    );
  ''';

  /// Index to guarantee fast FIFO (First-In, First-Out) queue processing.
  static const String createIndexOrder =
      '''
    CREATE INDEX idx_sync_queue_order ON $tableName ($colId ASC);
  ''';
}
