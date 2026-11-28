import 'package:sqflite/sqflite.dart';
import '../models/sync_queue_item_model.dart';
import '../tables/sync_queue_table.dart';

/// Data Access Object for the Transactional Outbox (sync_queue) table.
class SyncQueueDao {
  final Database db;

  const SyncQueueDao(this.db);

  DatabaseExecutor _executor(DatabaseExecutor? executor) => executor ?? db;

  /// Enqueues a new mutation to be synced to Cloud Firestore.
  Future<int> enqueue(
    SyncQueueItemModel item, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    return await exec.insert(SyncQueueTable.tableName, item.toMap());
  }

  /// Retrieves the next batch of pending mutations in FIFO order.
  Future<List<SyncQueueItemModel>> peekPendingItems({int limit = 50}) async {
    final results = await db.query(
      SyncQueueTable.tableName,
      orderBy: '${SyncQueueTable.colId} ASC',
      limit: limit,
    );

    return results.map(SyncQueueItemModel.fromMap).toList();
  }

  /// Deletes an outbox item upon confirmed synchronization with Cloud Firestore.
  Future<void> deleteItem(int id, {DatabaseExecutor? executor}) async {
    final exec = _executor(executor);
    await exec.delete(
      SyncQueueTable.tableName,
      where: '${SyncQueueTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Records a failed synchronization attempt, incrementing retry_count.
  Future<void> recordRetryFailure(int id, String errorMessage) async {
    await db.rawUpdate(
      '''
      UPDATE ${SyncQueueTable.tableName}
      SET ${SyncQueueTable.colRetryCount} = ${SyncQueueTable.colRetryCount} + 1,
          ${SyncQueueTable.colLastError} = ?
      WHERE ${SyncQueueTable.colId} = ?
      ''',
      [errorMessage, id],
    );
  }

  /// Returns total count of un-synchronized changes for a user.
  Future<int> getPendingCount(String userId) async {
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM ${SyncQueueTable.tableName}
      WHERE ${SyncQueueTable.colUserId} = ?
      ''',
      [userId],
    );

    if (result.isEmpty || result.first['count'] == null) return 0;
    return (result.first['count'] as num).toInt();
  }
}
