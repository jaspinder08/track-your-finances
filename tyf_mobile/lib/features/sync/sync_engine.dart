import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../database/tables/category_budget_table.dart';
import '../../database/tables/entry_table.dart';
import '../../database/tables/user_category_table.dart';

/// One row as stored in the cloud, with the server's write time.
class RemoteRow {
  const RemoteRow(this.data, this.serverTime);
  final Map<String, Object?> data;
  final DateTime serverTime;
}

/// The cloud side of sync. Firestore in the app, a fake in tests.
abstract class RemoteStore {
  /// The signed-in (non-guest) user's ID, or null if there isn't one.
  String? get uid;

  /// Rows written to [collection] after [since] (all rows if null).
  Future<List<RemoteRow>> pull(String collection, DateTime? since);

  /// Creates or replaces these rows (keyed by their `id`).
  Future<void> push(String collection, List<Map<String, Object?>> rows);
}

/// A synced table. [naturalKey]: columns that must be unique among live
/// rows, so the same category/budget made on two phones isn't doubled.
class SyncSpec {
  const SyncSpec(this.table, this.collection, {this.naturalKey = const []});
  final String table;
  final String collection;
  final List<String> naturalKey;
}

const syncSpecs = [
  SyncSpec(
    UserCategoryTable.tableName,
    'categories',
    naturalKey: [UserCategoryTable.colKind, UserCategoryTable.colName],
  ),
  SyncSpec(
    CategoryBudgetTable.tableName,
    'budgets',
    naturalKey: [CategoryBudgetTable.colCategory],
  ),
  SyncSpec(EntryTable.tableName, 'entries'),
];

/// Where sync keeps its own bookkeeping (which account, pull cursors).
abstract class SyncPrefs {
  String? getString(String key);
  Future<void> setString(String key, String value);
  int? getInt(String key);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
}

class SyncResult {
  const SyncResult({required this.changed, required this.pushed});

  /// Local rows changed by the pull (screens need reloading if > 0).
  final int changed;
  final int pushed;
}

/// Two-way sync between SQLite and the cloud. See docs/sync.md.
///
/// Per table: pull rows changed since the last pull and apply them
/// (newer `updated_at` wins), then push local rows not yet synced.
/// Deletes travel as rows with `is_deleted = 1`.
class SyncEngine {
  SyncEngine(this._helper, this._remote, this._prefs);
  final DatabaseHelper _helper;
  final RemoteStore _remote;
  final SyncPrefs _prefs;

  static const _kUid = 'sync_uid';
  static const _id = 'id';
  static const _updatedAt = 'updated_at';
  static const _isDeleted = 'is_deleted';
  static const _status = 'sync_status';

  /// Re-read a few minutes before the last cursor, in case two writes
  /// landed with near-identical server times. Applying a row twice is
  /// harmless.
  static const _overlap = Duration(minutes: 5);

  String _cursorKey(String uid, SyncSpec s) =>
      'sync_cursor_${uid}_${s.collection}';

  Future<SyncResult> sync() async {
    final uid = _remote.uid;
    if (uid == null) throw StateError('Not signed in');
    final db = await _helper.database;

    // A different account on this phone (or the first sync): everything
    // here must go up to it, which also merges guest data into it.
    if (_prefs.getString(_kUid) != uid) {
      for (final s in syncSpecs) {
        await _prefs.remove(_cursorKey(uid, s)); // download it all again
        await db.update(s.table, {
          _status: 'pending_update',
        }, where: "$_status = 'synced'");
      }
      await _prefs.setString(_kUid, uid);
    }

    var changed = 0, pushed = 0;
    for (final s in syncSpecs) {
      changed += await _pull(db, uid, s);
      pushed += await _push(db, s);
    }
    return SyncResult(changed: changed, pushed: pushed);
  }

  /// Removes every synced row from this phone and forgets which account
  /// it belonged to. Used on sign-out, after a successful backup, so the
  /// next person to sign in here never gets this account's data.
  Future<void> clearLocal() async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      for (final s in syncSpecs) {
        await txn.delete(s.table);
      }
    });
    await _prefs.remove(_kUid);
  }

  /// Rows changed here and not yet uploaded.
  Future<int> pendingCount() async {
    final db = await _helper.database;
    var n = 0;
    for (final s in syncSpecs) {
      n += (await db.query(s.table, where: "$_status != 'synced'")).length;
    }
    return n;
  }

  Future<int> _pull(Database db, String uid, SyncSpec s) async {
    final key = _cursorKey(uid, s);
    final cursor = _prefs.getInt(key);
    final remote = await _remote.pull(
      s.collection,
      cursor == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(cursor).subtract(_overlap),
    );
    if (remote.isEmpty) return 0;

    final columns = await _columns(db, s.table);
    final losers = <Map<String, Object?>>[]; // tombstones to push
    var changed = 0;
    var maxMs = cursor ?? 0;
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, Object?> tombstone(Map<String, Object?> row) =>
        {...row, _isDeleted: 1, _updatedAt: now}..remove(_status);

    await db.transaction((txn) async {
      for (final rr in remote) {
        maxMs = math.max(maxMs, rr.serverTime.millisecondsSinceEpoch);
        final r = {
          for (final c in columns)
            if (c != _status) c: rr.data[c],
        };
        final id = r[_id] as String?;
        final rUpdated = r[_updatedAt] as String?;
        if (id == null || rUpdated == null) continue;

        final local = (await txn.query(
          s.table,
          where: '$_id = ?',
          whereArgs: [id],
        )).firstOrNull;
        if (local != null) {
          final lUpdated = local[_updatedAt] as String;
          // Already have this version.
          if (lUpdated == rUpdated && local[_status] == 'synced') continue;
          // A newer local edit not yet pushed wins.
          if (local[_status] != 'synced' && lUpdated.compareTo(rUpdated) >= 0) {
            continue;
          }
        } else if (r[_isDeleted] == 1) {
          continue; // deleted somewhere else, never seen here
        }

        // Same category/budget made separately on another phone.
        if (s.naturalKey.isNotEmpty && r[_isDeleted] != 1) {
          final others = await txn.query(
            s.table,
            where: [
              for (final k in s.naturalKey) '$k = ?',
              '$_id != ?',
            ].join(' AND '),
            whereArgs: [for (final k in s.naturalKey) r[k], id],
          );
          final localWins = others.any(
            (o) =>
                o[_isDeleted] == 0 &&
                (o[_updatedAt] as String).compareTo(rUpdated) > 0,
          );
          if (localWins) {
            losers.add(tombstone(r));
            if (local != null) {
              await txn.delete(s.table, where: '$_id = ?', whereArgs: [id]);
              changed++;
            }
            continue;
          }
          for (final o in others) {
            await txn.delete(s.table, where: '$_id = ?', whereArgs: [o[_id]]);
            if (o[_status] != 'pending_create') losers.add(tombstone(o));
          }
        }

        await txn.insert(s.table, {
          ...r,
          _status: 'synced',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        changed++;
      }
    });

    if (losers.isNotEmpty) await _remote.push(s.collection, losers);
    await _prefs.setInt(key, maxMs);
    return changed;
  }

  Future<int> _push(Database db, SyncSpec s) async {
    final rows = await db.query(s.table, where: "$_status != 'synced'");
    if (rows.isEmpty) return 0;
    await _remote.push(s.collection, [
      for (final r in rows) Map.of(r)..remove(_status),
    ]);
    // Only if not edited again while uploading.
    final batch = db.batch();
    for (final r in rows) {
      batch.update(
        s.table,
        {_status: 'synced'},
        where: '$_id = ? AND $_updatedAt = ?',
        whereArgs: [r[_id], r[_updatedAt]],
      );
    }
    await batch.commit(noResult: true);
    return rows.length;
  }

  final _columnCache = <String, List<String>>{};
  Future<List<String>> _columns(DatabaseExecutor db, String table) async =>
      _columnCache[table] ??= [
        for (final r in await db.rawQuery('PRAGMA table_info($table)'))
          r['name'] as String,
      ];
}
