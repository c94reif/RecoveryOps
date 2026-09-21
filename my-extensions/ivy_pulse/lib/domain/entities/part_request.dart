import 'package:ivy_pulse/domain/entities/reference/priority_designator.dart';

/// A part an operator or maintainer wants ordered against a specific fault.
class PartRequest {
  final String nsn;
  final String name;
  final int quantity;
  final PriorityDesignator priority;

  /// TM item number of the fault that drove the request.
  final String? faultItemId;

  const PartRequest({
    required this.nsn,
    required this.name,
    this.quantity = 1,
    required this.priority,
    this.faultItemId,
  });

  Map<String, Object?> toMap() => {
        'nsn': nsn,
        'name': name,
        'quantity': quantity,
        'priorityCode': priority.code,
        'faultItemId': faultItemId,
      };
}
