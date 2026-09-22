import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/transaction_runner.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';

/// Atomically stores the report and marks its session submitted. The report
/// is safe on disk before publishing begins.
class SubmitSession {
  final SessionsRepository sessionsRepository;
  final FaultsRepository faultsRepository;
  final ReportsRepository reportsRepository;
  final BuildSessionReport buildSessionReport;
  final Clock clock;
  final TransactionRunner transactionRunner;

  const SubmitSession({
    required this.sessionsRepository,
    required this.faultsRepository,
    required this.reportsRepository,
    required this.buildSessionReport,
    required this.clock,
    required this.transactionRunner,
  });

  Future<PmcsReport> call(PmcsSession session) =>
      transactionRunner.run(() async {
        // Location may have arrived since the inspection screen loaded. Read it
        // inside the transaction so the report and the closed session agree.
        final persisted =
            await sessionsRepository.getBySessionId(session.sessionId);
        session = session.copyWith(
          latitude: persisted?.latitude,
          longitude: persisted?.longitude,
        );
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
      });
}
