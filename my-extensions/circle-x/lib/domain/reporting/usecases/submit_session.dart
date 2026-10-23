import 'package:circle_x/domain/reporting/entities/pmcs_report.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_session.dart';
import 'package:circle_x/domain/inspection/repositories/faults_repo.dart';
import 'package:circle_x/domain/reporting/repositories/reports_repo.dart';
import 'package:circle_x/domain/inspection/repositories/sessions_repo.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/shared/services/transaction_runner.dart';
import 'package:circle_x/domain/reporting/usecases/build_session_report.dart';

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
