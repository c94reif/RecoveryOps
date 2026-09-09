import 'package:recovery_ops/domain/entities/recovery_request.dart';

class ParsedRecoveryRequest {
  final String bumperNumber;
  final String issue;
  final RecoveryType? recoveryType;

  const ParsedRecoveryRequest({
    required this.bumperNumber,
    required this.issue,
    this.recoveryType,
  });
}
