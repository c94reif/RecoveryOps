import 'package:recovery_ops/domain/entities/parsed_recovery_request.dart';

abstract class TranscriptParserStrategy {
  Future<ParsedRecoveryRequest> parse(String transcript);
}
