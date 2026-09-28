import 'dart:convert';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';

abstract final class PmcsStorageCodec {
  static String encodePhases(List<PmcsPhase> phases) =>
      phases.map((phase) => phase.wireName).join(',');

  static String? encodeSignature(PmcsSignature? signature) =>
      signature == null ? null : jsonEncode(signature.toMap());

  static PmcsSignature? decodeSignature(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return PmcsSignature.fromMap(jsonDecode(json) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  static List<PmcsPhase> decodePhases(String value) {
    if (value.isEmpty) return const [];
    return value
        .split(',')
        .map(PmcsPhase.tryFromWireName)
        .whereType<PmcsPhase>()
        .toList();
  }

  static String encodeFaults(List<PmcsFault> faults) =>
      jsonEncode(faults.map((fault) => fault.toMap()).toList());

  static List<PmcsFault> decodeFaults(String entityId, String json) {
    if (json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((fault) =>
              PmcsFault.fromMap(entityId, fault as Map<String, Object?>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
