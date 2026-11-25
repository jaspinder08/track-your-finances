import 'package:equatable/equatable.dart';
import '../tables/user_table.dart';

/// Database representation of a User record in SQLite.
class UserModel extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String currencyCode;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.currencyCode = 'USD',
    this.role = 'user',
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  /// Converts a SQLite Map row into a strongly-typed [UserModel].
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map[UserTable.colId] as String,
      email: map[UserTable.colEmail] as String,
      displayName: map[UserTable.colDisplayName] as String?,
      currencyCode: map[UserTable.colCurrencyCode] as String? ?? 'USD',
      role: map[UserTable.colRole] as String? ?? 'user',
      createdAt: DateTime.parse(map[UserTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[UserTable.colUpdatedAt] as String),
      lastSyncedAt: map[UserTable.colLastSyncedAt] != null
          ? DateTime.parse(map[UserTable.colLastSyncedAt] as String)
          : null,
    );
  }

  /// Converts a [UserModel] into a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      UserTable.colId: id,
      UserTable.colEmail: email,
      UserTable.colDisplayName: displayName,
      UserTable.colCurrencyCode: currencyCode,
      UserTable.colRole: role,
      UserTable.colCreatedAt: createdAt.toUtc().toIso8601String(),
      UserTable.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
      UserTable.colLastSyncedAt: lastSyncedAt?.toUtc().toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? currencyCode,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      currencyCode: currencyCode ?? this.currencyCode,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    currencyCode,
    role,
    createdAt,
    updatedAt,
    lastSyncedAt,
  ];
}
