import 'package:ivy_pulse/domain/entities/fault_severity.dart';

/// One operator answer to one TM check.
///
/// [severity] is null when [faultIndex] is 0 — the component is serviceable
/// and no fault is raised.
class CheckResult {
  final String itemId;
  final int faultIndex;
  final String faultLabel;
  final FaultSeverity? severity;
  final String? note;
  final DateTime recordedAt;

  const CheckResult({
    required this.itemId,
    required this.faultIndex,
    required this.faultLabel,
    required this.severity,
    this.note,
    required this.recordedAt,
  });

  bool get isServiceable => faultIndex == 0;
  bool get isFault => faultIndex != 0;

  CheckResult copyWith({
    int? faultIndex,
    String? faultLabel,
    FaultSeverity? severity,
    String? note,
    DateTime? recordedAt,
    bool clearSeverity = false,
    bool clearNote = false,
  }) {
    return CheckResult(
      itemId: itemId,
      faultIndex: faultIndex ?? this.faultIndex,
      faultLabel: faultLabel ?? this.faultLabel,
      severity: clearSeverity ? null : (severity ?? this.severity),
      note: clearNote ? null : (note ?? this.note),
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
