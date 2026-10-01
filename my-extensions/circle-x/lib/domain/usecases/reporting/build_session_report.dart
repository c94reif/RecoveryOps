import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/services/clock.dart';

class BuildSessionReport {
  final Clock clock;

  const BuildSessionReport(this.clock);

  PmcsReport call({
    required PmcsSession session,
    required List<PmcsFault> faults,
    String fromCallsign = 'You',
  }) {
    return PmcsReport(
      entityId: session.sessionId,
      fromCallsign: fromCallsign,
      bumperNumber: session.bumperNumber,
      vehicleType: session.vehicleType,
      operator: session.operator,
      uic: session.uic,
      phases: session.completedPhases,
      faults: faults,
      signature: session.signature,
      latitude: session.latitude ?? 0,
      longitude: session.longitude ?? 0,
      timestamp: clock.nowUtc(),
      isOutgoing: true,
      isRead: true,
    );
  }
}
