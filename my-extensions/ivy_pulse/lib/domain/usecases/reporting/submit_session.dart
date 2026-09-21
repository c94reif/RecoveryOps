import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';

/// Closes a PMCS out: stores the report locally first, then marks the session
/// submitted. Publishing is deliberately *not* part of this — the report is
/// safe on disk before a single packet leaves the device.
class SubmitSession {
  final SessionsRepository sessionsRepository;
  final FaultsRepository faultsRepository;
  final ReportsRepository reportsRepository;
  final BuildSessionReport buildSessionReport;
  final Clock clock;

  const SubmitSession({
    required this.sessionsRepository,
    required this.faultsRepository,
    required this.reportsRepository,
    required this.buildSessionReport,
    required this.clock,
  });

  Future<PmcsReport> call(PmcsSession session) async {
    final faults = await faultsRepository.getForSession(session.sessionId);
    final report = buildSessionReport(session: session, faults: faults);
    final stored = await reportsRepository.insertReport(report);

    await sessionsRepository.update(
      session.copyWith(
        status: SessionStatus.submitted,
        submittedAt: clock.nowUtc(),
      ),
    );

    return stored;
  }
}
