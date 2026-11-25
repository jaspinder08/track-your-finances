import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tyf_mobile/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  // Initialize FFI for headless desktop SQLite testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late UserDao userDao;
  late CategoryDao categoryDao;
  late TransactionDao transactionDao;
  late SyncQueueDao syncQueueDao;

  const uuid = Uuid();
  final testUserId = uuid.v4();
  final now = DateTime.now().toUtc();

  setUp(() async {
    // Open a fresh in-memory database for each test
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(UserTable.createTableQuery);
          batch.execute(CategoryTable.createTableQuery);
          batch.execute(TransactionTable.createTableQuery);
          batch.execute(BudgetTable.createTableQuery);
          batch.execute(SyncQueueTable.createTableQuery);

          batch.execute(CategoryTable.createIndexUserDeleted);
          batch.execute(TransactionTable.createIndexUserDate);
          batch.execute(TransactionTable.createIndexCategory);
          batch.execute(TransactionTable.createIndexSync);
          batch.execute(BudgetTable.createIndexUserPeriod);
          batch.execute(SyncQueueTable.createIndexOrder);
          await batch.commit(noResult: true);
        },
      ),
    );

    userDao = UserDao(db);
    categoryDao = CategoryDao(db);
    transactionDao = TransactionDao(db);
    BudgetDao(db);
    syncQueueDao = SyncQueueDao(db);

    // Seed test user
    await userDao.upsertUser(
      UserModel(
        id: testUserId,
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Schema & Foreign Key Constraints', () {
    test('enforces foreign key constraints on transactions', () async {
      final fakeCategoryId = uuid.v4();

      final invalidTx = TransactionModel(
        id: uuid.v4(),
        userId: testUserId,
        categoryId: fakeCategoryId, // Does not exist in categories table
        amountCents: 2500,
        type: 'expense',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // Attempting to insert a transaction with a non-existent category must throw DatabaseException
      expect(
        () async => await transactionDao.insertTransaction(invalidTx),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('enforces amount_cents > 0 check constraint', () async {
      // Create a valid category first
      final catId = uuid.v4();
      await categoryDao.insertCategory(
        CategoryModel(
          id: catId,
          userId: testUserId,
          name: 'Groceries',
          type: 'expense',
          iconKey: 'cart',
          colorHex: '#00FF00',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final zeroAmountTx = TransactionModel(
        id: uuid.v4(),
        userId: testUserId,
        categoryId: catId,
        amountCents: 0, // Violates CHECK(amount_cents > 0)
        type: 'expense',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () async => await transactionDao.insertTransaction(zeroAmountTx),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('CategoryDao Operations', () {
    test('seeds default categories if none exist', () async {
      await categoryDao.seedDefaultCategories(testUserId);
      final categories = await categoryDao.getCategories(testUserId);

      expect(categories.length, equals(CategoryDao.defaultCategories.length));
      expect(categories.any((c) => c.name == 'Groceries'), isTrue);
      expect(categories.any((c) => c.name == 'Salary'), isTrue);

      // Calling seed a second time should be idempotent (no duplicates)
      await categoryDao.seedDefaultCategories(testUserId);
      final categoriesAfterSecondSeed = await categoryDao.getCategories(
        testUserId,
      );
      expect(
        categoriesAfterSecondSeed.length,
        equals(CategoryDao.defaultCategories.length),
      );
    });

    test('soft deletes category properly', () async {
      final catId = uuid.v4();
      await categoryDao.insertCategory(
        CategoryModel(
          id: catId,
          userId: testUserId,
          name: 'Coffee',
          type: 'expense',
          iconKey: 'cafe',
          colorHex: '#6F4E37',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await categoryDao.softDeleteCategory(catId);

      // Should not be in active categories
      final active = await categoryDao.getCategories(
        testUserId,
        includeDeleted: false,
      );
      expect(active.any((c) => c.id == catId), isFalse);

      // Should still be visible when includeDeleted is true
      final all = await categoryDao.getCategories(
        testUserId,
        includeDeleted: true,
      );
      final deleted = all.firstWhere((c) => c.id == catId);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.syncStatus, equals('pending_delete'));
    });
  });

  group('TransactionDao Operations & Aggregations', () {
    test(
      'calculates accurate total amount in cents without float precision bugs',
      () async {
        final catId = uuid.v4();
        await categoryDao.insertCategory(
          CategoryModel(
            id: catId,
            userId: testUserId,
            name: 'Dining',
            type: 'expense',
            iconKey: 'food',
            colorHex: '#FF5722',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Add $10.50 (1050 cents) and $20.49 (2049 cents)
        await transactionDao.insertTransaction(
          TransactionModel(
            id: uuid.v4(),
            userId: testUserId,
            categoryId: catId,
            amountCents: 1050,
            type: 'expense',
            transactionDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await transactionDao.insertTransaction(
          TransactionModel(
            id: uuid.v4(),
            userId: testUserId,
            categoryId: catId,
            amountCents: 2049,
            type: 'expense',
            transactionDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final start = now.subtract(const Duration(days: 1));
        final end = now.add(const Duration(days: 1));

        final totalCents = await transactionDao.getTotalAmountCents(
          userId: testUserId,
          type: 'expense',
          startDate: start,
          endDate: end,
        );

        // 1050 + 2049 = 3099 cents ($30.99 exact)
        expect(totalCents, equals(3099));
      },
    );
  });

  group('SyncQueueDao Outbox Pattern', () {
    test('enqueues and peeks items in FIFO order', () async {
      final txId1 = uuid.v4();
      final txId2 = uuid.v4();

      final id1 = await syncQueueDao.enqueue(
        SyncQueueItemModel(
          userId: testUserId,
          entityType: 'transaction',
          entityId: txId1,
          operation: 'CREATE',
          payloadJson: '{"amount": 100}',
          createdAt: now,
        ),
      );

      final id2 = await syncQueueDao.enqueue(
        SyncQueueItemModel(
          userId: testUserId,
          entityType: 'transaction',
          entityId: txId2,
          operation: 'UPDATE',
          payloadJson: '{"amount": 200}',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );

      final pending = await syncQueueDao.peekPendingItems();
      expect(pending.length, equals(2));
      expect(pending[0].id, equals(id1));
      expect(pending[0].entityId, equals(txId1));
      expect(pending[1].id, equals(id2));
      expect(pending[1].entityId, equals(txId2));

      // Delete the first item
      await syncQueueDao.deleteItem(id1);
      final remaining = await syncQueueDao.peekPendingItems();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(id2));
    });

    test('increments retry count on failure', () async {
      final itemId = await syncQueueDao.enqueue(
        SyncQueueItemModel(
          userId: testUserId,
          entityType: 'category',
          entityId: uuid.v4(),
          operation: 'CREATE',
          payloadJson: '{}',
          createdAt: now,
        ),
      );

      await syncQueueDao.recordRetryFailure(itemId, '503 Service Unavailable');
      final items = await syncQueueDao.peekPendingItems();
      expect(items.first.retryCount, equals(1));
      expect(items.first.lastError, equals('503 Service Unavailable'));
    });
  });

  group('Atomic Dual-Write Transaction Guarantee', () {
    test(
      'rolls back both entity and sync queue if an error occurs mid-transaction',
      () async {
        final catId = uuid.v4();
        await categoryDao.insertCategory(
          CategoryModel(
            id: catId,
            userId: testUserId,
            name: 'Bills',
            type: 'expense',
            iconKey: 'receipt',
            colorHex: '#0000FF',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final txId = uuid.v4();

        try {
          await db.transaction((txn) async {
            // 1. Insert transaction
            await transactionDao.insertTransaction(
              TransactionModel(
                id: txId,
                userId: testUserId,
                categoryId: catId,
                amountCents: 5000,
                type: 'expense',
                transactionDate: now,
                createdAt: now,
                updatedAt: now,
              ),
              executor: txn,
            );

            // 2. Simulate failure before/during sync_queue insert
            throw Exception('Simulated crash during atomic dual-write');
          });
        } catch (_) {
          // Expected exception
        }

        // Verify transaction table does NOT contain the aborted transaction
        final tx = await transactionDao.getTransactionById(txId);
        expect(
          tx,
          isNull,
          reason: 'Aborted transaction must be rolled back completely',
        );

        // Verify sync queue is empty
        final queueItems = await syncQueueDao.peekPendingItems();
        expect(queueItems.isEmpty, isTrue);
      },
    );
  });
}
