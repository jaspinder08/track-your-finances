import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'tables/user_table.dart';
import 'tables/category_table.dart';
import 'tables/transaction_table.dart';
import 'tables/budget_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/entry_table.dart';
import 'tables/category_budget_table.dart';
import 'tables/user_category_table.dart';

/// Manages the SQLite database lifecycle: initialization, opening,
/// schema migrations, pragmas, and connection caching.
///
/// **Crucial Production Details:**
/// 1. Foreign keys are DISABLED by default in SQLite! We explicitly enable them
///    in [onConfigure] using `PRAGMA foreign_keys = ON;`.
/// 2. We enable Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) for high concurrency,
///    allowing reading while a background sync write is in progress.
/// 3. Supports an in-memory override for lightning-fast unit tests.
class DatabaseHelper {
  static const String _defaultDatabaseName = 'tyf_database.db';
  static const int _databaseVersion = 5;

  Database? _database;
  final String databaseName;

  /// Private constructor for singleton instance.
  DatabaseHelper._internal({this.databaseName = _defaultDatabaseName});

  /// The standard singleton instance for production use.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Factory constructor to support custom database names or test databases.
  factory DatabaseHelper.withName(String customDbName) {
    return DatabaseHelper._internal(databaseName: customDbName);
  }

  /// Accessor for the active SQLite database instance. Opens lazily if needed.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Allows unit tests to inject a pre-opened in-memory database.
  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  /// Initializes the SQLite connection and configures callbacks.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, databaseName);

    return await openDatabase(
      fullPath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Invoked first when the database is created or opened.
  /// Enforces foreign key constraints and enables WAL mode.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
    // In-memory databases do not support WAL mode, so we apply WAL conditionally
    if (databaseName != inMemoryDatabasePath) {
      // journal_mode returns a row, so Android requires rawQuery, not execute.
      await db.rawQuery('PRAGMA journal_mode = WAL;');
    }
  }

  /// Runs when the database file is first created.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Create tables in dependency order
    batch.execute(UserTable.createTableQuery);
    batch.execute(CategoryTable.createTableQuery);
    batch.execute(TransactionTable.createTableQuery);
    batch.execute(BudgetTable.createTableQuery);
    batch.execute(SyncQueueTable.createTableQuery);

    // 2. Create performance indices
    batch.execute(CategoryTable.createIndexUserDeleted);
    batch.execute(TransactionTable.createIndexUserDate);
    batch.execute(TransactionTable.createIndexCategory);
    batch.execute(TransactionTable.createIndexSync);
    batch.execute(BudgetTable.createIndexUserPeriod);
    batch.execute(SyncQueueTable.createIndexOrder);
    batch.execute(EntryTable.createTableQuery);
    batch.execute(EntryTable.createIndexDate);
    batch.execute(CategoryBudgetTable.createTableQuery);
    batch.execute(UserCategoryTable.createTableQuery);

    await batch.commit(noResult: true);
  }

  /// Handles schema migrations as the app evolves across releases.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: add the `entries` table used by the add sheet.
    if (oldVersion < 2) {
      await db.execute(EntryTable.createTableQuery);
      await db.execute(EntryTable.createIndexDate);
    } else if (oldVersion < 3) {
      // v3: series_id (a fresh v2 create above already includes it).
      await db.execute(EntryTable.addSeriesIdColumn);
    }
    // v4: per-category monthly budgets.
    if (oldVersion < 4) {
      await db.execute(CategoryBudgetTable.createTableQuery);
    }
    // v5: user-editable categories.
    if (oldVersion < 5) {
      await db.execute(UserCategoryTable.createTableQuery);
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
