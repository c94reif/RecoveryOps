// import 'dart:convert';
// // import 'package:flutter_gemma/flutter_gemma.dart';
// import 'package:recovery_ops/domain/entities/parsedRecoveryRequest.dart';
// import 'package:recovery_ops/domain/entities/recoveryRequest.dart';
// import 'package:recovery_ops/domain/services/transcriptParserStrategy.dart';
//
// class LlmTranscriptParser implements TranscriptParserStrategy {
//   bool initialized = false;
//
//   Future<void> ensureInitialized() async {
//     if (!initialized) {
//       await FlutterGemmaPlugin.instance.init(
//         maxTokens: 256,
//         temperature: 0.0,
//         topK: 1,
//       );
//       initialized = true;
//     }
//   }
//
//   @override
//   Future<ParsedRecoveryRequest> parse(String transcript) async {
//     final trimmed = transcript.trim();
//     if (trimmed.isEmpty) {
//       return const ParsedRecoveryRequest(
//         bumperNumber: '',
//         issue: '',
//       );
//     }
//
//     await ensureInitialized();
//
//     final prompt = '''Extract the following fields from this vehicle recovery request. Respond ONLY with valid JSON, no other text.
//
// Fields:
// - bumperNumber: the vehicle identifier (e.g. HQ-23, BR-07)
// - issue: the problem description
// - recoveryType: either "towBar" or "wrecker" if mentioned, otherwise null
//
// Request: "$trimmed"
//
// JSON:''';
//
//     final response = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
//
//     if (response == null || response.trim().isEmpty) {
//       return ParsedRecoveryRequest(
//         bumperNumber: '',
//         issue: trimmed,
//       );
//     }
//
//     return parseJsonResponse(response, trimmed);
//   }
//
//   ParsedRecoveryRequest parseJsonResponse(String response, String fallback) {
//     try {
//       final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
//       if (jsonMatch == null) {
//         return ParsedRecoveryRequest(bumperNumber: '', issue: fallback);
//       }
//
//       final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
//
//       final bumper = (json['bumperNumber'] as String?)?.trim() ?? '';
//       final issue = (json['issue'] as String?)?.trim() ?? '';
//       final typeStr = json['recoveryType'] as String?;
//
//       RecoveryType? recoveryType;
//       if (typeStr != null) {
//         final lower = typeStr.toLowerCase();
//         if (lower.contains('wrecker')) {
//           recoveryType = RecoveryType.wrecker;
//         } else if (lower.contains('tow')) {
//           recoveryType = RecoveryType.towBar;
//         }
//       }
//
//       return ParsedRecoveryRequest(
//         bumperNumber: bumper,
//         issue: issue,
//         recoveryType: recoveryType,
//       );
//     } catch (_) {
//       return ParsedRecoveryRequest(bumperNumber: '', issue: fallback);
//     }
//   }
// }
