import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';

abstract class FaultsRepository {
  Future<List<PmcsFault>> getForSession(String sessionId);

  /// Replaces the stored faults for a phase with [faults] — completing a phase
  /// a second time must not double up.
  Future<void> replacePhaseFaults(
    String sessionId,
    List<PmcsFault> faults, {
    required String phaseWireName,
  });

  Future<void> deleteForSession(String sessionId);
}
