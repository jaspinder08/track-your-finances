import 'package:equatable/equatable.dart';
import '../tables/sync_queue_table.dart';

/// Representation of an Outbox item queued for Firebase synchronization.
class SyncQueueItemModel extends Equatable {
  final int? id; // Auto-incremented primary key
  final String userId;
  final String entityType; // 'transaction', 'category', 'budget', 'user'
  final String entityId; // The UUID of the target entity
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String payloadJson;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;

  const SyncQueueItemModel({
    this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
  });

  factory SyncQueueItemModel.fromMap(Map<String, dynamic> map) {
    return SyncQueueItemModel(
      id: map[SyncQueueTable.colId] as int?,
      userId: map[SyncQueueTable.colUserId] as String,
      entityType: map[SyncQueueTable.colEntityType] as String,
      entityId: map[SyncQueueTable.colEntityId] as String,
      operation: map[SyncQueueTable.colOperation] as String,
      payloadJson: map[SyncQueueTable.colPayloadJson] as String,
      retryCount: map[SyncQueueTable.colRetryCount] as int? ?? 0,
      lastError: map[SyncQueueTable.colLastError] as String?,
      createdAt: DateTime.parse(map[SyncQueueTable.colCreatedAt] as String),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      SyncQueueTable.colUserId: userId,
      SyncQueueTable.colEntityType: entityType,
      SyncQueueTable.colEntityId: entityId,
      SyncQueueTable.colOperation: operation,
      SyncQueueTable.colPayloadJson: payloadJson,
      SyncQueueTable.colRetryCount: retryCount,
      SyncQueueTable.colLastError: lastError,
      SyncQueueTable.colCreatedAt: createdAt.toUtc().toIso8601String(),
    };
    if (id != null) {
      map[SyncQueueTable.colId] = id;
    }
    return map;
  }

  SyncQueueItemModel copyWith({
    int? id,
    String? userId,
    String? entityType,
    String? entityId,
    String? operation,
    String? payloadJson,
    int? retryCount,
    String? lastError,
    DateTime? createdAt,
  }) {
    return SyncQueueItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    entityType,
    entityId,
    operation,
    payloadJson,
    retryCount,
    lastError,
    createdAt,
  ];
}
