import 'package:circle_x/domain/entities/reference/priority_designator.dart';

class PartRequest {
  final String nsn;
  final String name;
  final int quantity;
  final PriorityDesignator priority;

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
