import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';

abstract class FaultsRepository {
  Future<List<PmcsFault>> getForSession(String sessionId);

  Future<void> replacePhaseFaults(
    String sessionId,
    List<PmcsFault> faults, {
    required String phaseWireName,
  });

  Future<void> deleteForSession(String sessionId);
}
