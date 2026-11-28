import 'package:equatable/equatable.dart';
import '../tables/budget_table.dart';

/// Database representation of a Budget in SQLite.
class BudgetModel extends Equatable {
  final String id;
  final String userId;
  final String categoryId;
  final int limitCents;
  final int month;
  final int year;
  final bool isDeleted;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.limitCents,
    required this.month,
    required this.year,
    this.isDeleted = false,
    this.syncStatus = 'pending_create',
    required this.createdAt,
    required this.updatedAt,
  });

  double get limit => limitCents / 100.0;

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map[BudgetTable.colId] as String,
      userId: map[BudgetTable.colUserId] as String,
      categoryId: map[BudgetTable.colCategoryId] as String,
      limitCents: map[BudgetTable.colLimitCents] as int,
      month: map[BudgetTable.colMonth] as int,
      year: map[BudgetTable.colYear] as int,
      isDeleted: (map[BudgetTable.colIsDeleted] as int) == 1,
      syncStatus: map[BudgetTable.colSyncStatus] as String,
      createdAt: DateTime.parse(map[BudgetTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[BudgetTable.colUpdatedAt] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      BudgetTable.colId: id,
      BudgetTable.colUserId: userId,
      BudgetTable.colCategoryId: categoryId,
      BudgetTable.colLimitCents: limitCents,
      BudgetTable.colMonth: month,
      BudgetTable.colYear: year,
      BudgetTable.colIsDeleted: isDeleted ? 1 : 0,
      BudgetTable.colSyncStatus: syncStatus,
      BudgetTable.colCreatedAt: createdAt.toUtc().toIso8601String(),
      BudgetTable.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
    };
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    int? limitCents,
    int? month,
    int? year,
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      limitCents: limitCents ?? this.limitCents,
      month: month ?? this.month,
      year: year ?? this.year,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    categoryId,
    limitCents,
    month,
    year,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
}
