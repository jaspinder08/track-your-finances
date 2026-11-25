import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../database/database_helper.dart';
import '../../../database/tables/entry_table.dart';
import 'entry.dart';
import 'recurrence.dart';
import 'transaction_options.dart';

/// Where entries are stored. SQLite in the app; in memory in tests.
abstract class EntryRepository {
  Future<List<Entry>> all();

  /// Every row, including soft-deleted ones (used for recurrence).
  Future<List<Entry>> allRows();

  /// [id]: a fixed ID (recurring copies use one, so two phones creating
  /// the same copy make one row). Adding an ID that exists does nothing.
  Future<Entry> add(EntryDraft draft, {String? seriesId, String? id});
  Future<Entry> update(Entry entry, EntryDraft draft);
  Future<void> delete(String id);

  /// Renames a category on every entry of [type] that uses it.
  Future<void> renameCategory(EntryType type, String from, String to);
}

/// SQLite-backed store, the app's source of truth.
class SqliteEntryRepository implements EntryRepository {
  SqliteEntryRepository(this._helper);
  final DatabaseHelper _helper;
  static const _uuid = Uuid();
  static final _day = DateFormat('yyyy-MM-dd');

  @override
  Future<List<Entry>> all() async {
    final db = await _helper.database;
    final rows = await db.query(
      EntryTable.tableName,
      where: '${EntryTable.colIsDeleted} = 0',
      orderBy:
          '${EntryTable.colEntryDate} DESC, ${EntryTable.colCreatedAt} DESC',
    );
    return rows.map(fromRow).toList();
  }

  @override
  Future<List<Entry>> allRows() async {
    final db = await _helper.database;
    return (await db.query(EntryTable.tableName)).map(fromRow).toList();
  }

  @override
  Future<Entry> add(EntryDraft draft, {String? seriesId, String? id}) async {
    final now = DateTime.now().toUtc();
    final entry = Entry(
      id: id ?? _uuid.v4(),
      data: draft,
      createdAt: now,
      updatedAt: now,
      seriesId: seriesId,
    );
    final db = await _helper.database;
    await db.insert(
      EntryTable.tableName,
      toRow(entry),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return entry;
  }

  /// Replaces an entry's fields. A row never synced stays pending_create;
  /// otherwise it becomes pending_update so the change syncs later.
  @override
  Future<Entry> update(Entry entry, EntryDraft draft) async {
    final updated = Entry(
      id: entry.id,
      data: draft,
      createdAt: entry.createdAt,
      updatedAt: DateTime.now().toUtc(),
      seriesId: entry.seriesId,
    );
    final db = await _helper.database;
    final row = toRow(updated)..remove(EntryTable.colCreatedAt);
    await db.rawUpdate(
      'UPDATE ${EntryTable.tableName} SET '
      '${row.keys.map((k) => '$k = ?').join(', ')}, '
      "${EntryTable.colSyncStatus} = CASE ${EntryTable.colSyncStatus} "
      "WHEN 'pending_create' THEN 'pending_create' ELSE 'pending_update' END "
      'WHERE ${EntryTable.colId} = ?',
      [...row.values, entry.id],
    );
    return updated;
  }

  /// Soft delete, so the deletion can sync later.
  @override
  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.update(
      EntryTable.tableName,
      {
        EntryTable.colIsDeleted: 1,
        EntryTable.colSyncStatus: 'pending_delete',
        EntryTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${EntryTable.colId} = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> renameCategory(EntryType type, String from, String to) async {
    final db = await _helper.database;
    await db.rawUpdate(
      'UPDATE ${EntryTable.tableName} SET ${EntryTable.colCategory} = ?, '
      '${EntryTable.colUpdatedAt} = ?, '
      "${EntryTable.colSyncStatus} = CASE ${EntryTable.colSyncStatus} "
      "WHEN 'pending_create' THEN 'pending_create' ELSE 'pending_update' END "
      'WHERE ${EntryTable.colCategory} = ? AND ${EntryTable.colType} = ?',
      [to, DateTime.now().toUtc().toIso8601String(), from, type.name],
    );
  }

  static Map<String, Object?> toRow(Entry e) {
    final d = e.data;
    return {
      EntryTable.colId: e.id,
      EntryTable.colType: d.type.name,
      EntryTable.colAmountPaise: d.amountPaise,
      EntryTable.colEntryDate: _day.format(d.date),
      EntryTable.colName: d.name,
      EntryTable.colDescription: d.description,
      EntryTable.colCategory: d.category,
      EntryTable.colSubcategory: d.subcategory,
      EntryTable.colPaymentMethod: d.paymentMethod,
      EntryTable.colFromAccount: d.fromAccount,
      EntryTable.colToAccount: d.toAccount,
      EntryTable.colSavedSoFarPaise: d.savedSoFarPaise,
      EntryTable.colRepeatEvery: d.repeat?.every,
      EntryTable.colRepeatUnit: d.repeat?.unit.name,
      EntryTable.colSeriesId: e.seriesId,
      EntryTable.colCreatedAt: e.createdAt.toIso8601String(),
      EntryTable.colUpdatedAt: e.updatedAt.toIso8601String(),
    };
  }

  static Entry fromRow(Map<String, Object?> r) {
    final every = r[EntryTable.colRepeatEvery] as int?;
    final unit = r[EntryTable.colRepeatUnit] as String?;
    return Entry(
      id: r[EntryTable.colId] as String,
      createdAt: DateTime.parse(r[EntryTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(r[EntryTable.colUpdatedAt] as String),
      seriesId: r[EntryTable.colSeriesId] as String?,
      isDeleted: r[EntryTable.colIsDeleted] == 1,
      data: EntryDraft(
        type: EntryType.values.byName(r[EntryTable.colType] as String),
        amountPaise: r[EntryTable.colAmountPaise] as int,
        date: _day.parse(r[EntryTable.colEntryDate] as String),
        name: r[EntryTable.colName] as String?,
        description: r[EntryTable.colDescription] as String?,
        category: r[EntryTable.colCategory] as String?,
        subcategory: r[EntryTable.colSubcategory] as String?,
        paymentMethod: r[EntryTable.colPaymentMethod] as String?,
        fromAccount: r[EntryTable.colFromAccount] as String?,
        toAccount: r[EntryTable.colToAccount] as String?,
        savedSoFarPaise: r[EntryTable.colSavedSoFarPaise] as int?,
        repeat: every != null && unit != null
            ? Repeat(every: every, unit: RepeatUnit.values.byName(unit))
            : null,
      ),
    );
  }
}

/// Non-persistent store for widget tests.
class InMemoryEntryRepository implements EntryRepository {
  final _items = <Entry>[];
  var _next = 0;

  final _deleted = <Entry>[];

  @override
  Future<List<Entry>> all() async => List.of(_items);

  @override
  Future<List<Entry>> allRows() async => allRowsSync();
  List<Entry> allRowsSync() => [..._items, ..._deleted];

  @override
  Future<Entry> add(EntryDraft draft, {String? seriesId, String? id}) async {
    final existing = allRowsSync().where((e) => e.id == id).firstOrNull;
    if (existing != null) return existing;
    final now = DateTime.now().toUtc();
    final e = Entry(
      id: id ?? '${_next++}',
      data: draft,
      createdAt: now,
      updatedAt: now,
      seriesId: seriesId,
    );
    _items.add(e);
    return e;
  }

  @override
  Future<Entry> update(Entry entry, EntryDraft draft) async {
    final updated = Entry(
      id: entry.id,
      data: draft,
      createdAt: entry.createdAt,
      updatedAt: DateTime.now().toUtc(),
      seriesId: entry.seriesId,
    );
    final i = _items.indexWhere((e) => e.id == entry.id);
    if (i >= 0) _items[i] = updated;
    return updated;
  }

  @override
  Future<void> renameCategory(EntryType type, String from, String to) async {
    for (var i = 0; i < _items.length; i++) {
      final e = _items[i];
      if (e.type != type || e.data.category != from) continue;
      final d = e.data;
      _items[i] = Entry(
        id: e.id,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        seriesId: e.seriesId,
        data: EntryDraft(
          type: d.type,
          amountPaise: d.amountPaise,
          date: d.date,
          name: d.name,
          description: d.description,
          category: to,
          subcategory: d.subcategory,
          paymentMethod: d.paymentMethod,
          fromAccount: d.fromAccount,
          toAccount: d.toAccount,
          savedSoFarPaise: d.savedSoFarPaise,
          repeat: d.repeat,
        ),
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    for (final e in _items.where((e) => e.id == id)) {
      _deleted.add(
        Entry(
          id: e.id,
          data: e.data,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
          seriesId: e.seriesId,
          isDeleted: true,
        ),
      );
    }
    _items.removeWhere((e) => e.id == id);
  }
}

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => SqliteEntryRepository(DatabaseHelper.instance),
);

/// All saved entries, newest first. Screens watch this.
final entriesProvider = AsyncNotifierProvider<EntriesNotifier, List<Entry>>(
  EntriesNotifier.new,
);

class EntriesNotifier extends AsyncNotifier<List<Entry>> {
  EntryRepository get _repo => ref.read(entryRepositoryProvider);

  @override
  Future<List<Entry>> build() async {
    final repo = ref.watch(entryRepositoryProvider);
    await createDueRecurring(repo, DateTime.now());
    return repo.all();
  }

  /// Saves the entry, plus any copies already due if it repeats and is
  /// back-dated (e.g. rent from 3 months ago adds the missed months).
  Future<void> add(EntryDraft draft) async {
    await _repo.add(draft);
    if (draft.repeat != null) await createDueRecurring(_repo, DateTime.now());
    state = AsyncData(await _repo.all());
  }

  Future<void> edit(String id, EntryDraft draft) async {
    final current = state.value ?? const <Entry>[];
    final old = current.firstWhere((e) => e.id == id);
    await _repo.update(old, draft);
    if (draft.repeat != null) await createDueRecurring(_repo, DateTime.now());
    state = AsyncData(await _repo.all());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData([
      for (final e in state.value ?? const <Entry>[])
        if (e.id != id) e,
    ]);
  }
}

/// Income minus expense across all entries.
final balanceProvider = Provider<int>((ref) {
  final entries = ref.watch(entriesProvider).value ?? const [];
  return entries.fold(0, (sum, e) => sum + e.balanceEffect);
});

/// Entries grouped by calendar day.
final entriesByDayProvider = Provider<Map<DateTime, List<Entry>>>((ref) {
  final map = <DateTime, List<Entry>>{};
  for (final e in ref.watch(entriesProvider).value ?? const <Entry>[]) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    (map[d] ??= []).add(e);
  }
  return map;
});

/// Creates the copies of recurring entries that are due up to [now].
/// The latest existing copy (even a deleted one) is the starting point, so
/// deleting a copy doesn't bring it back. Copies don't repeat themselves.
/// Returns how many were created.
Future<int> createDueRecurring(EntryRepository repo, DateTime now) async {
  final rows = await repo.allRows();
  final today = DateTime(now.year, now.month, now.day);
  var created = 0;
  for (final root in rows.where((e) => e.isSeriesRoot && !e.isDeleted)) {
    var last = root.date;
    for (final c in rows.where((e) => e.seriesId == root.id)) {
      if (c.date.isAfter(last)) last = c.date;
    }
    final d = root.data;
    for (final date in dueDates(
      start: root.date,
      repeat: d.repeat!,
      after: last,
      today: today,
    )) {
      await repo.add(
        EntryDraft(
          type: d.type,
          amountPaise: d.amountPaise,
          date: date,
          name: d.name,
          description: d.description,
          category: d.category,
          subcategory: d.subcategory,
          paymentMethod: d.paymentMethod,
        ),
        seriesId: root.id,
        id: '${root.id}-${SqliteEntryRepository._day.format(date)}',
      );
      created++;
    }
  }
  return created;
}
