import 'package:recovery_ops/domain/entities/parsedRecoveryRequest.dart';

abstract class TranscriptParserStrategy {
  Future<ParsedRecoveryRequest> parse(String transcript);
}
