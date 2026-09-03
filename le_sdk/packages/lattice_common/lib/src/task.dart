import 'package:flutter/foundation.dart';

/// High-level UI status groups derived from Lattice task proto statuses.
enum TaskStatusGroup {
  /// Task is awaiting action (CREATED, SCHEDULED, SENT, MACHINE_RECEIPT, ACK, WILCO).
  pending,

  /// Task is actively being executed (EXECUTING, WAITING_FOR_UPDATE, PAUSED).
  active,

  /// Task has reached a terminal state (DONE_OK, DONE_NOT_OK, REPLACED, VERSION_REJECTED).
  terminal,
}

/// Lightweight entity reference associated with a task.
@immutable
class TaskEntityData {
  const TaskEntityData({
    required this.entityId,
    this.displayName,
    this.latitude,
    this.longitude,
    this.isSnapshot = false,
  });

  /// The entity ID.
  final String entityId;

  /// Optional human-readable display name.
  final String? displayName;

  /// Optional latitude in decimal degrees.
  final double? latitude;

  /// Optional longitude in decimal degrees.
  final double? longitude;

  /// Whether this entity data is a snapshot taken at task creation time.
  final bool isSnapshot;

  factory TaskEntityData.fromJson(Map<String, dynamic> json) {
    return TaskEntityData(
      entityId: json['entityId'] as String,
      displayName: json['displayName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isSnapshot: json['isSnapshot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        if (displayName != null) 'displayName': displayName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isSnapshot': isSnapshot,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskEntityData &&
          runtimeType == other.runtimeType &&
          entityId == other.entityId;

  @override
  int get hashCode => entityId.hashCode;

  @override
  String toString() => 'TaskEntityData(id: $entityId, name: $displayName)';
}

/// A single status transition event in a task's lifecycle.
@immutable
class TaskEvent {
  const TaskEvent({
    required this.timestamp,
    required this.rawStatus,
    required this.statusLabel,
    this.updatedBy,
  });

  final DateTime timestamp;
  final int rawStatus;
  final String statusLabel;

  /// Display name (callsign) of the user or entity that triggered this update.
  final String? updatedBy;

  factory TaskEvent.fromJson(Map<String, dynamic> json) => TaskEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        rawStatus: json['rawStatus'] as int,
        statusLabel: json['statusLabel'] as String,
        updatedBy: json['updatedBy'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'rawStatus': rawStatus,
        'statusLabel': statusLabel,
        if (updatedBy != null) 'updatedBy': updatedBy,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskEvent &&
          timestamp == other.timestamp &&
          rawStatus == other.rawStatus;

  @override
  int get hashCode => Object.hash(timestamp, rawStatus);

  @override
  String toString() => 'TaskEvent($statusLabel @ $timestamp)';
}

/// Parameters for creating a new task via [TaskRepository].
@immutable
class CreateTaskParams {
  const CreateTaskParams({
    required this.specificationTypeUrl,
    required this.specificationBytes,
    required this.description,
    this.assigneeEntityId,
    this.parentTaskId,
    this.initialEntities = const [],
  });

  /// Protobuf type URL for the task specification.
  final String specificationTypeUrl;

  /// Raw serialised bytes of the specification payload.
  final List<int> specificationBytes;

  /// Human-readable description of the task.
  final String description;

  /// Optional entity ID of the assignee.
  final String? assigneeEntityId;

  /// Optional parent task ID (for sub-tasks).
  final String? parentTaskId;

  /// Entities associated with this task at creation time.
  final List<TaskEntityData> initialEntities;

  @override
  String toString() =>
      'CreateTaskParams(typeUrl: $specificationTypeUrl, '
      'description: $description, assignee: $assigneeEntityId, '
      'parent: $parentTaskId, entities: ${initialEntities.length})';
}

/// Immutable wrapper around all data belonging to a single Lattice task.
///
/// Use [TaskData.fromValues] to construct instances and
/// [TaskData.statusGroupFromRawStatus] / [TaskData.statusLabelFromRawStatus]
/// to interpret the raw proto status integer independently.
@immutable
class TaskData {
  /// Creates a [TaskData] directly.
  const TaskData({
    required this.taskId,
    required this.specificationTypeUrl,
    required this.specificationBytes,
    required this.statusGroup,
    required this.rawStatus,
    required this.statusLabel,
    required this.createTime,
    required this.lastUpdateTime,
    required this.description,
    required this.initialEntities,
    this.assigneeEntityId,
    this.authorUserId,
    this.parentTaskId,
    this.lastUpdatedByUserId,
    this.lastUpdatedByEntityId,
    this.errorMessage,
    this.errorCode,
    this.statusHistory = const [],
  });

  /// Constructs a [TaskData] from individual field values, deriving
  /// [statusGroup] and [statusLabel] automatically from [rawStatus].
  factory TaskData.fromValues({
    required String taskId,
    required String specificationTypeUrl,
    required List<int> specificationBytes,
    required int rawStatus,
    required DateTime createTime,
    required DateTime lastUpdateTime,
    required String description,
    required List<TaskEntityData> initialEntities,
    String? assigneeEntityId,
    String? authorUserId,
    String? parentTaskId,
    String? lastUpdatedByUserId,
    String? lastUpdatedByEntityId,
    String? errorMessage,
    int? errorCode,
    List<TaskEvent> statusHistory = const [],
  }) {
    return TaskData(
      taskId: taskId,
      specificationTypeUrl: specificationTypeUrl,
      specificationBytes: specificationBytes,
      rawStatus: rawStatus,
      statusGroup: TaskData.statusGroupFromRawStatus(rawStatus),
      statusLabel: TaskData.statusLabelFromRawStatus(rawStatus),
      createTime: createTime,
      lastUpdateTime: lastUpdateTime,
      description: description,
      initialEntities: initialEntities,
      assigneeEntityId: assigneeEntityId,
      authorUserId: authorUserId,
      parentTaskId: parentTaskId,
      lastUpdatedByUserId: lastUpdatedByUserId,
      lastUpdatedByEntityId: lastUpdatedByEntityId,
      errorMessage: errorMessage,
      errorCode: errorCode,
      statusHistory: statusHistory,
    );
  }

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Unique identifier for this task.
  final String taskId;

  /// Fully-qualified protobuf type URL for the specification.
  final String specificationTypeUrl;

  /// Raw serialised bytes of the google.protobuf.Any specification payload.
  final List<int> specificationBytes;

  /// High-level UI status group derived from [rawStatus].
  final TaskStatusGroup statusGroup;

  /// Raw proto integer status value as returned by the Lattice API.
  final int rawStatus;

  /// Human-readable label for the current task status.
  final String statusLabel;

  /// Optional entity ID of the assigned unit or system.
  final String? assigneeEntityId;

  /// Optional user ID of the task author.
  final String? authorUserId;

  /// Optional ID of the parent task if this is a sub-task.
  final String? parentTaskId;

  /// User ID of whoever last updated this task (from Principal.user).
  final String? lastUpdatedByUserId;

  /// Entity ID of whatever system last updated this task (from Principal.system).
  final String? lastUpdatedByEntityId;

  /// Task creation timestamp (UTC).
  final DateTime createTime;

  /// Timestamp of the most recent task update (UTC).
  final DateTime lastUpdateTime;

  /// Human-readable description of the task.
  final String description;

  /// Optional human-readable error message from a TaskError payload.
  final String? errorMessage;

  /// Optional raw error code from a TaskError payload.
  final int? errorCode;

  /// Entities associated with this task.
  final List<TaskEntityData> initialEntities;

  /// Chronological history of status transitions (most recent first).
  final List<TaskEvent> statusHistory;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Returns true when the task has reached a terminal state.
  bool get isTerminal => statusGroup == TaskStatusGroup.terminal;

  /// Returns true when the task is in a pending state.
  bool get isPending => statusGroup == TaskStatusGroup.pending;

  /// Returns true when the task is actively being executed.
  bool get isActive => statusGroup == TaskStatusGroup.active;

  /// Returns true when the task has been WILCO'd (status 6).
  bool get isWilco => rawStatus == 6;

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Maps a raw proto status integer to a [TaskStatusGroup].
  ///
  /// Proto status values (anduril.taskmanager.v1):
  ///  0 - STATUS_INVALID
  ///  1 - CREATED
  ///  2 - SCHEDULED_IN_MANAGER
  ///  3 - SENT
  ///  4 - MACHINE_RECEIPT
  ///  5 - ACK
  ///  6 - WILCO
  ///  7 - EXECUTING
  ///  8 - WAITING_FOR_UPDATE
  ///  9 - DONE_OK
  /// 10 - DONE_NOT_OK
  /// 11 - REPLACED
  /// 12 - CANCEL_REQUESTED
  /// 13 - COMPLETE_REQUESTED
  /// 14 - VERSION_REJECTED
  /// 15 - PAUSED
  static TaskStatusGroup statusGroupFromRawStatus(int rawStatus) {
    switch (rawStatus) {
      case 1: // CREATED
      case 2: // SCHEDULED_IN_MANAGER
      case 3: // SENT
      case 4: // MACHINE_RECEIPT
      case 5: // ACK
      case 6: // WILCO
      case 12: // CANCEL_REQUESTED
      case 13: // COMPLETE_REQUESTED
        return TaskStatusGroup.pending;

      case 7: // EXECUTING
      case 8: // WAITING_FOR_UPDATE
      case 15: // PAUSED
        return TaskStatusGroup.active;

      case 9: // DONE_OK
      case 10: // DONE_NOT_OK
      case 11: // REPLACED
      case 14: // VERSION_REJECTED
        return TaskStatusGroup.terminal;

      default:
        return TaskStatusGroup.pending;
    }
  }

  /// Returns a human-readable label for a raw proto status integer.
  static String statusLabelFromRawStatus(int rawStatus) {
    switch (rawStatus) {
      case 1:
        return 'Created';
      case 2:
        return 'Scheduled';
      case 3:
        return 'Sent';
      case 4:
        return 'Acknowledged (Machine)';
      case 5:
        return 'Acknowledged';
      case 6:
        return 'Will Comply';
      case 7:
        return 'Executing';
      case 8:
        return 'Waiting for Update';
      case 9:
        return 'Completed';
      case 10:
        return 'Failed';
      case 11:
        return 'Replaced';
      case 12:
        return 'Cancel Requested';
      case 13:
        return 'Complete Requested';
      case 14:
        return 'Rejected';
      case 15:
        return 'Paused';
      default:
        return 'Unknown';
    }
  }

  // ---------------------------------------------------------------------------
  // JSON serialization
  // ---------------------------------------------------------------------------

  factory TaskData.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['rawStatus'] as int;
    return TaskData(
      taskId: json['taskId'] as String,
      specificationTypeUrl: json['specificationTypeUrl'] as String,
      specificationBytes: (json['specificationBytes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      rawStatus: rawStatus,
      statusGroup: TaskData.statusGroupFromRawStatus(rawStatus),
      statusLabel: json['statusLabel'] as String? ??
          TaskData.statusLabelFromRawStatus(rawStatus),
      createTime: DateTime.parse(json['createTime'] as String),
      lastUpdateTime: DateTime.parse(json['lastUpdateTime'] as String),
      description: json['description'] as String? ?? '',
      initialEntities: (json['initialEntities'] as List<dynamic>?)
              ?.map((e) =>
                  TaskEntityData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      assigneeEntityId: json['assigneeEntityId'] as String?,
      authorUserId: json['authorUserId'] as String?,
      parentTaskId: json['parentTaskId'] as String?,
      lastUpdatedByUserId: json['lastUpdatedByUserId'] as String?,
      lastUpdatedByEntityId: json['lastUpdatedByEntityId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errorCode: json['errorCode'] as int?,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((e) => TaskEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'specificationTypeUrl': specificationTypeUrl,
        'specificationBytes': specificationBytes,
        'rawStatus': rawStatus,
        'statusGroup': statusGroup.name,
        'statusLabel': statusLabel,
        'createTime': createTime.toIso8601String(),
        'lastUpdateTime': lastUpdateTime.toIso8601String(),
        'description': description,
        'initialEntities': initialEntities.map((e) => e.toJson()).toList(),
        if (assigneeEntityId != null) 'assigneeEntityId': assigneeEntityId,
        if (authorUserId != null) 'authorUserId': authorUserId,
        if (parentTaskId != null) 'parentTaskId': parentTaskId,
        if (lastUpdatedByUserId != null)
          'lastUpdatedByUserId': lastUpdatedByUserId,
        if (lastUpdatedByEntityId != null)
          'lastUpdatedByEntityId': lastUpdatedByEntityId,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (errorCode != null) 'errorCode': errorCode,
        if (statusHistory.isNotEmpty)
          'statusHistory': statusHistory.map((e) => e.toJson()).toList(),
      };

  // ---------------------------------------------------------------------------
  // Equality / hashing
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskData &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId &&
          rawStatus == other.rawStatus;

  @override
  int get hashCode => Object.hash(taskId, rawStatus);

  @override
  String toString() =>
      'TaskData(id: $taskId, status: $statusLabel ($rawStatus), '
      'group: $statusGroup, assignee: $assigneeEntityId)';
}
