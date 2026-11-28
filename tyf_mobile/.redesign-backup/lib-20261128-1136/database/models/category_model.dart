import 'package:equatable/equatable.dart';
import '../tables/category_table.dart';

/// Database representation of a Category record in SQLite.
class CategoryModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String iconKey;
  final String colorHex;
  final bool isDefault;
  final bool isDeleted;
  final String
  syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorHex,
    this.isDefault = false,
    this.isDeleted = false,
    this.syncStatus = 'pending_create',
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map[CategoryTable.colId] as String,
      userId: map[CategoryTable.colUserId] as String,
      name: map[CategoryTable.colName] as String,
      type: map[CategoryTable.colType] as String,
      iconKey: map[CategoryTable.colIconKey] as String,
      colorHex: map[CategoryTable.colColorHex] as String,
      isDefault: (map[CategoryTable.colIsDefault] as int) == 1,
      isDeleted: (map[CategoryTable.colIsDeleted] as int) == 1,
      syncStatus: map[CategoryTable.colSyncStatus] as String,
      createdAt: DateTime.parse(map[CategoryTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[CategoryTable.colUpdatedAt] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      CategoryTable.colId: id,
      CategoryTable.colUserId: userId,
      CategoryTable.colName: name,
      CategoryTable.colType: type,
      CategoryTable.colIconKey: iconKey,
      CategoryTable.colColorHex: colorHex,
      CategoryTable.colIsDefault: isDefault ? 1 : 0,
      CategoryTable.colIsDeleted: isDeleted ? 1 : 0,
      CategoryTable.colSyncStatus: syncStatus,
      CategoryTable.colCreatedAt: createdAt.toUtc().toIso8601String(),
      CategoryTable.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? iconKey,
    String? colorHex,
    bool? isDefault,
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
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
    name,
    type,
    iconKey,
    colorHex,
    isDefault,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
}
