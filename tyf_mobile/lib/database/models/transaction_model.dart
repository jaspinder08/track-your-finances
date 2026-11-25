import 'package:equatable/equatable.dart';
import '../tables/transaction_table.dart';

/// Database representation of a Transaction in SQLite.
class TransactionModel extends Equatable {
  final String id;
  final String userId;
  final String categoryId;
  final int amountCents; // Guaranteed integer cents
  final String type; // 'income' or 'expense'
  final DateTime transactionDate;
  final String? note;
  final String? payeePayer;
  final bool isDeleted;
  final String
  syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amountCents,
    required this.type,
    required this.transactionDate,
    this.note,
    this.payeePayer,
    this.isDeleted = false,
    this.syncStatus = 'pending_create',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper to get decimal representation for display purposes only.
  double get amount => amountCents / 100.0;

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map[TransactionTable.colId] as String,
      userId: map[TransactionTable.colUserId] as String,
      categoryId: map[TransactionTable.colCategoryId] as String,
      amountCents: map[TransactionTable.colAmountCents] as int,
      type: map[TransactionTable.colType] as String,
      transactionDate: DateTime.parse(
        map[TransactionTable.colTransactionDate] as String,
      ),
      note: map[TransactionTable.colNote] as String?,
      payeePayer: map[TransactionTable.colPayeePayer] as String?,
      isDeleted: (map[TransactionTable.colIsDeleted] as int) == 1,
      syncStatus: map[TransactionTable.colSyncStatus] as String,
      createdAt: DateTime.parse(map[TransactionTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[TransactionTable.colUpdatedAt] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      TransactionTable.colId: id,
      TransactionTable.colUserId: userId,
      TransactionTable.colCategoryId: categoryId,
      TransactionTable.colAmountCents: amountCents,
      TransactionTable.colType: type,
      TransactionTable.colTransactionDate: transactionDate
          .toUtc()
          .toIso8601String(),
      TransactionTable.colNote: note,
      TransactionTable.colPayeePayer: payeePayer,
      TransactionTable.colIsDeleted: isDeleted ? 1 : 0,
      TransactionTable.colSyncStatus: syncStatus,
      TransactionTable.colCreatedAt: createdAt.toUtc().toIso8601String(),
      TransactionTable.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    int? amountCents,
    String? type,
    DateTime? transactionDate,
    String? note,
    String? payeePayer,
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      note: note ?? this.note,
      payeePayer: payeePayer ?? this.payeePayer,
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
    amountCents,
    type,
    transactionDate,
    note,
    payeePayer,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
}
