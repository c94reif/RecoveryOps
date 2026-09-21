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

/// Raw values of the `anduril.taskmanager.v1.Status` proto enum, carried on
/// [TaskData.rawStatus].
///
/// Kept as plain int constants (not a Dart `enum`) for the same reason as
/// [TaskErrorCode]: they compare directly against the raw int that round-trips
/// through gRPC, JSON, and the mock backend, with no conversion hop at every
/// boundary. Critically, the status space is **open** — extensions define their
/// own statuses well above the proto range (e.g. 100 PENDING_REVIEW, 101
/// COORDINATED) and [TaskData.statusGroupFromRawStatus] has a `default:` arm to
/// absorb them. An enum would have to close that space or carry an `unknown`
/// case that every call site re-widens to an int anyway.
///
/// Use these instead of bare literals — `task.rawStatus == TaskStatus.wilco`
/// reads as doctrine; `task.rawStatus == 6` does not.
abstract final class TaskStatus {
  /// STATUS_INVALID.
  static const int invalid = 0;

  /// CREATED — task exists but has not been dispatched.
  static const int created = 1;

  /// SCHEDULED_IN_MANAGER.
  static const int scheduled = 2;

  /// SENT — dispatched to the assignee, awaiting acknowledgement.
  static const int sent = 3;

  /// MACHINE_RECEIPT — received by the assignee's system.
  static const int machineReceipt = 4;

  /// ACK — acknowledged by the assignee.
  static const int ack = 5;

  /// WILCO — the assignee accepted the task ("will comply"). On a CFF child
  /// fire mission this is the gun crew accepting the mission.
  static const int wilco = 6;

  /// EXECUTING — actively being worked. On a fire mission: rounds away
  /// ("Shot Out").
  static const int executing = 7;

  /// WAITING_FOR_UPDATE — the assignee needs input to continue. On a fire
  /// mission: rounds impacted ("Splash"), awaiting the FO's adjust-or-end call.
  static const int waitingForUpdate = 8;

  /// DONE_OK — completed successfully ("End Mission" on a fire mission).
  static const int doneOk = 9;

  /// DONE_NOT_OK — terminal failure. Disambiguated by [TaskErrorCode]: only
  /// [TaskErrorCode.rejected] is a deliberate decline (CANTCO).
  static const int doneNotOk = 10;

  /// REPLACED — superseded by a newer definition version.
  static const int replaced = 11;

  /// CANCEL_REQUESTED.
  static const int cancelRequested = 12;

  /// COMPLETE_REQUESTED.
  static const int completeRequested = 13;

  /// VERSION_REJECTED — the server refused the submitted definition version.
  static const int versionRejected = 14;

  /// PAUSED.
  static const int paused = 15;
}

/// Raw values of the `anduril.taskmanager.v1.ErrorCode` proto enum, carried on
/// a task's `TaskError.code` and surfaced as [TaskData.errorCode].
///
/// A terminal [TaskStatus.doneNotOk] is disambiguated by this code:
///  - [rejected] — the assignee deliberately declined the task (CANTCO).
///  - [cancelled] — the task was cancelled by the requester.
///  - [failed] / absent — a generic or system failure.
///
/// Kept as plain int constants (not an enum) so they compare directly against
/// the raw int that round-trips through gRPC, JSON, and the mock backend.
///
/// These mirror the generated `ErrorCode` enum in
/// `package:lattice_sdk_dart/anduril/taskmanager/v1/task.pub.pbenum.dart`.
/// `lattice_common` intentionally does not depend on the heavyweight generated
/// proto package (it depends only on `flutter`), so the values are mirrored
/// here — exactly as the proto status ints are mirrored in
/// [TaskData.statusGroupFromRawStatus]. App-layer code that already imports the
/// proto package (e.g. `LatticeTaskRepository`) should use `tm.ErrorCode`
/// directly when encoding to the wire; this mirror is for the shared types
/// layer and UI.
abstract final class TaskErrorCode {
  /// ERROR_CODE_INVALID — no/unknown error code.
  static const int invalid = 0;

  /// ERROR_CODE_CANCELLED — task cancelled by the requester.
  static const int cancelled = 1;

  /// ERROR_CODE_REJECTED — assignee declined the task (CANTCO).
  static const int rejected = 2;

  /// ERROR_CODE_TIMEOUT — task timed out.
  static const int timeout = 3;

  /// ERROR_CODE_FAILED — generic failure.
  static const int failed = 4;
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
  String toString() => 'CreateTaskParams(typeUrl: $specificationTypeUrl, '
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
    this.progressTypeUrl,
    this.progressBytes,
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
    String? progressTypeUrl,
    List<int>? progressBytes,
  }) {
    return TaskData(
      taskId: taskId,
      specificationTypeUrl: specificationTypeUrl,
      specificationBytes: specificationBytes,
      rawStatus: rawStatus,
      statusGroup: TaskData.statusGroupFromRawStatus(rawStatus),
      statusLabel: TaskData.statusLabelFromStatus(rawStatus, errorCode),
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
      progressTypeUrl: progressTypeUrl,
      progressBytes: progressBytes,
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

  /// Type URL of the task's incremental progress payload (`TaskStatus.progress`,
  /// a `google.protobuf.Any`), or null when no progress has been reported.
  /// Carries whatever progress message the task type defines, e.g.
  /// `type.googleapis.com/com.example.tasks.SomeTaskProgress`.
  final String? progressTypeUrl;

  /// Raw bytes of the task's progress payload (the `Any`'s value), or null.
  /// The assignee packs a task-type-specific progress message here via
  /// UpdateTaskStatus; clients decode it with the message matching
  /// [progressTypeUrl].
  final List<int>? progressBytes;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Returns true when the task has reached a terminal state.
  bool get isTerminal => statusGroup == TaskStatusGroup.terminal;

  /// Whether this task was deliberately declined by its assignee (CANTCO).
  ///
  /// True only for a terminal DONE_NOT_OK carrying [TaskErrorCode.rejected]. A
  /// generic failure (ERROR_CODE_FAILED, no code) or a cancellation
  /// (ERROR_CODE_CANCELLED) is not a CANTCO.
  bool get isCantco =>
      rawStatus == TaskStatus.doneNotOk && errorCode == TaskErrorCode.rejected;

  /// Returns true when the task is in a pending state.
  bool get isPending => statusGroup == TaskStatusGroup.pending;

  /// Returns true when the task is actively being executed.
  bool get isActive => statusGroup == TaskStatusGroup.active;

  /// Returns true when the task has been WILCO'd (status 6).
  bool get isWilco => rawStatus == TaskStatus.wilco;

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Maps a raw proto status integer to a [TaskStatusGroup]. See [TaskStatus]
  /// for the value names.
  static TaskStatusGroup statusGroupFromRawStatus(int rawStatus) {
    switch (rawStatus) {
      case TaskStatus.created:
      case TaskStatus.scheduled:
      case TaskStatus.sent:
      case TaskStatus.machineReceipt:
      case TaskStatus.ack:
      case TaskStatus.wilco:
      case TaskStatus.cancelRequested:
      case TaskStatus.completeRequested:
        return TaskStatusGroup.pending;

      case TaskStatus.executing:
      case TaskStatus.waitingForUpdate:
      case TaskStatus.paused:
        return TaskStatusGroup.active;

      case TaskStatus.doneOk:
      case TaskStatus.doneNotOk:
      case TaskStatus.replaced:
      case TaskStatus.versionRejected:
        return TaskStatusGroup.terminal;

      // Extension-defined statuses (e.g. 100 PENDING_REVIEW) land here.
      default:
        return TaskStatusGroup.pending;
    }
  }

  /// Returns a human-readable label for a raw proto status integer.
  static String statusLabelFromRawStatus(int rawStatus) {
    switch (rawStatus) {
      case TaskStatus.created:
        return 'Created';
      case TaskStatus.scheduled:
        return 'Scheduled';
      case TaskStatus.sent:
        return 'Sent';
      case TaskStatus.machineReceipt:
        return 'Acknowledged (Machine)';
      case TaskStatus.ack:
        return 'Acknowledged';
      case TaskStatus.wilco:
        return 'Will Comply';
      case TaskStatus.executing:
        return 'Executing';
      case TaskStatus.waitingForUpdate:
        return 'Waiting for Update';
      case TaskStatus.doneOk:
        return 'Completed';
      case TaskStatus.doneNotOk:
        return 'Failed';
      case TaskStatus.replaced:
        return 'Replaced';
      case TaskStatus.cancelRequested:
        return 'Cancel Requested';
      case TaskStatus.completeRequested:
        return 'Complete Requested';
      case TaskStatus.versionRejected:
        return 'Rejected';
      case TaskStatus.paused:
        return 'Paused';
      default:
        return 'Unknown';
    }
  }

  /// Returns a human-readable label for a [rawStatus], refined by [errorCode].
  ///
  /// A terminal DONE_NOT_OK is generically "Failed", but when it carries
  /// [TaskErrorCode.rejected] it represents a deliberate decline (CANTCO) and is
  /// labelled "Cannot Comply"; with [TaskErrorCode.cancelled] it is "Cancelled".
  /// All other statuses defer to [statusLabelFromRawStatus].
  static String statusLabelFromStatus(int rawStatus, int? errorCode) {
    if (rawStatus == TaskStatus.doneNotOk) {
      if (errorCode == TaskErrorCode.rejected) return 'Cannot Comply';
      if (errorCode == TaskErrorCode.cancelled) return 'Cancelled';
    }
    return statusLabelFromRawStatus(rawStatus);
  }

  // ---------------------------------------------------------------------------
  // JSON serialization
  // ---------------------------------------------------------------------------

  factory TaskData.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['rawStatus'] as int;
    final errorCode = json['errorCode'] as int?;
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
          TaskData.statusLabelFromStatus(rawStatus, errorCode),
      createTime: DateTime.parse(json['createTime'] as String),
      lastUpdateTime: DateTime.parse(json['lastUpdateTime'] as String),
      description: json['description'] as String? ?? '',
      initialEntities: (json['initialEntities'] as List<dynamic>?)
              ?.map((e) => TaskEntityData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      assigneeEntityId: json['assigneeEntityId'] as String?,
      authorUserId: json['authorUserId'] as String?,
      parentTaskId: json['parentTaskId'] as String?,
      lastUpdatedByUserId: json['lastUpdatedByUserId'] as String?,
      lastUpdatedByEntityId: json['lastUpdatedByEntityId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errorCode: errorCode,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((e) => TaskEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      progressTypeUrl: json['progressTypeUrl'] as String?,
      progressBytes: (json['progressBytes'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
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
        if (progressTypeUrl != null) 'progressTypeUrl': progressTypeUrl,
        if (progressBytes != null) 'progressBytes': progressBytes,
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
