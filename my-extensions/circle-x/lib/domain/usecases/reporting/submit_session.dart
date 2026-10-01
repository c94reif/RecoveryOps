import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/repositories/faults_repo.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/transaction_runner.dart';
import 'package:circle_x/domain/usecases/reporting/build_session_report.dart';

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
