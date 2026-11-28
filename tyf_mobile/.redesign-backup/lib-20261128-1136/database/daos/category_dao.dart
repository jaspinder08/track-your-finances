import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../tables/category_table.dart';

/// Data Access Object for category persistence and system-default seeding.
class CategoryDao {
  final Database db;

  const CategoryDao(this.db);

  DatabaseExecutor _executor(DatabaseExecutor? executor) => executor ?? db;

  /// Default categories automatically seeded when a user registers or logs in.
  static const List<Map<String, String>> defaultCategories = [
    {
      'name': 'Groceries',
      'type': 'expense',
      'icon': 'shopping_cart',
      'color': '#4CAF50',
    },
    {
      'name': 'Dining Out',
      'type': 'expense',
      'icon': 'restaurant',
      'color': '#FF9800',
    },
    {
      'name': 'Housing & Rent',
      'type': 'expense',
      'icon': 'home',
      'color': '#2196F3',
    },
    {
      'name': 'Utilities',
      'type': 'expense',
      'icon': 'bolt',
      'color': '#9C27B0',
    },
    {
      'name': 'Transportation',
      'type': 'expense',
      'icon': 'directions_car',
      'color': '#00BCD4',
    },
    {
      'name': 'Entertainment',
      'type': 'expense',
      'icon': 'movie',
      'color': '#E91E63',
    },
    {
      'name': 'Healthcare',
      'type': 'expense',
      'icon': 'local_hospital',
      'color': '#F44336',
    },
    {
      'name': 'Salary',
      'type': 'income',
      'icon': 'account_balance_wallet',
      'color': '#3F51B5',
    },
    {
      'name': 'Investments',
      'type': 'income',
      'icon': 'trending_up',
      'color': '#009688',
    },
    {
      'name': 'Other Income',
      'type': 'income',
      'icon': 'attach_money',
      'color': '#8BC34A',
    },
  ];

  /// Seeds standard categories for a new user if none exist.
  Future<void> seedDefaultCategories(
    String userId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    final existing = await exec.query(
      CategoryTable.tableName,
      where: '${CategoryTable.colUserId} = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    const uuid = Uuid();
    final batch = db.batch();

    for (final cat in defaultCategories) {
      final category = CategoryModel(
        id: uuid.v4(),
        userId: userId,
        name: cat['name']!,
        type: cat['type']!,
        iconKey: cat['icon']!,
        colorHex: cat['color']!,
        isDefault: true,
        isDeleted: false,
        syncStatus: 'pending_create',
        createdAt: now,
        updatedAt: now,
      );
      batch.insert(CategoryTable.tableName, category.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// Retrieves active categories for a user.
  Future<List<CategoryModel>> getCategories(
    String userId, {
    String? type,
    bool includeDeleted = false,
  }) async {
    final whereClauses = <String>['${CategoryTable.colUserId} = ?'];
    final whereArgs = <dynamic>[userId];

    if (!includeDeleted) {
      whereClauses.add('${CategoryTable.colIsDeleted} = 0');
    }

    if (type != null) {
      whereClauses.add('${CategoryTable.colType} = ?');
      whereArgs.add(type);
    }

    final results = await db.query(
      CategoryTable.tableName,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: '${CategoryTable.colName} ASC',
    );

    return results.map(CategoryModel.fromMap).toList();
  }

  /// Retrieves a single category by ID.
  Future<CategoryModel?> getCategoryById(
    String categoryId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    final results = await exec.query(
      CategoryTable.tableName,
      where: '${CategoryTable.colId} = ?',
      whereArgs: [categoryId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CategoryModel.fromMap(results.first);
  }

  /// Inserts a newly created category.
  Future<void> insertCategory(
    CategoryModel category, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.insert(
      CategoryTable.tableName,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing category.
  Future<void> updateCategory(
    CategoryModel category, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      CategoryTable.tableName,
      category.toMap(),
      where: '${CategoryTable.colId} = ?',
      whereArgs: [category.id],
    );
  }

  /// Soft deletes a category.
  Future<void> softDeleteCategory(
    String categoryId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      CategoryTable.tableName,
      {
        CategoryTable.colIsDeleted: 1,
        CategoryTable.colSyncStatus: 'pending_delete',
        CategoryTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${CategoryTable.colId} = ?',
      whereArgs: [categoryId],
    );
  }

  /// Updates synchronization status.
  Future<void> updateSyncStatus(
    String categoryId,
    String status, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _executor(executor);
    await exec.update(
      CategoryTable.tableName,
      {
        CategoryTable.colSyncStatus: status,
        CategoryTable.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${CategoryTable.colId} = ?',
      whereArgs: [categoryId],
    );
  }
}
