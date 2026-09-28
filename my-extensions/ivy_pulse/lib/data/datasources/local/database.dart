import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ivy_pulse/data/datasources/local/tables/dismissed_fault_suggestions_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/report_withdrawals_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/check_results_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_faults_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_reports_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_sessions_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/profile_table.dart';
import 'package:ivy_pulse/data/datasources/local/tables/queued_submissions_table.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    PmcsSessions,
    CheckResults,
    PmcsFaults,
    PmcsReports,
    QueuedSubmissions,
    ReportWithdrawals,
    DismissedFaultSuggestions,
  ],
  daos: [
    ProfileDao,
    SessionsDao,
    CheckResultsDao,
    PmcsFaultsDao,
    PmcsReportsDao,
    QueuedSubmissionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.test(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, fromVersion, toVersion) async {
          if (fromVersion < 2) {
            await migrator.alterTable(
              TableMigration(
                profiles,
                columnTransformer: {
                  profiles.uic: const CustomExpression<String>('unit'),
                },
              ),
            );
            await migrator.renameColumn(pmcsSessions, 'unit', pmcsSessions.uic);
            await migrator.renameColumn(pmcsReports, 'unit', pmcsReports.uic);
            await migrator.addColumn(pmcsSessions, pmcsSessions.signatureJson);
            await migrator.addColumn(pmcsReports, pmcsReports.signatureJson);
          }
          if (fromVersion < 3) {
            await transaction(() async {
              await customStatement("""
                UPDATE pmcs_reports SET is_read = (
                  SELECT MAX(other.is_read) FROM pmcs_reports AS other
                  WHERE other.entity_id = pmcs_reports.entity_id
                ) WHERE entity_id <> ''
              """);
              await customStatement("""
                DELETE FROM pmcs_reports WHERE entity_id <> '' AND id <> (
                  SELECT other.id FROM pmcs_reports AS other
                  WHERE other.entity_id = pmcs_reports.entity_id
                  ORDER BY other.is_outgoing DESC,
                    (other.signature_json IS NOT NULL) DESC,
                    other.timestamp DESC, other.id DESC LIMIT 1
                )
              """);
              await migrator.createIndex(pmcsReportsEntityId);
            });
          }
          if (fromVersion < 4) {
            await migrator.createTable(reportWithdrawals);
          }
          if (fromVersion < 5) {
            await migrator.createTable(dismissedFaultSuggestions);
          }
        },
      );
}

QueryExecutor openConnection() {
  return driftDatabase(
    name: 'ivy_pulse_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
