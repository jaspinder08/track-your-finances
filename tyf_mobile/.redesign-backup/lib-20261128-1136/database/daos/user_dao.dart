import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../tables/user_table.dart';

/// Data Access Object (DAO) for user profile and sync metadata operations in SQLite.
class UserDao {
  final Database db;

  const UserDao(this.db);

  /// Inserts or replaces a user profile record in SQLite.
  Future<void> upsertUser(UserModel user) async {
    await db.insert(
      UserTable.tableName,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a user by their Firebase UID.
  Future<UserModel?> getUserById(String userId) async {
    final results = await db.query(
      UserTable.tableName,
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  /// Updates the remote pull synchronization timestamp high-water mark.
  Future<void> updateLastSyncedAt(String userId, DateTime timestamp) async {
    await db.update(
      UserTable.tableName,
      {
        UserTable.colLastSyncedAt: timestamp.toUtc().toIso8601String(),
        UserTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }
}
