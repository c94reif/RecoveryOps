import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 — the profile stopped carrying a name and a rank. Who walked
          // the vehicle is read off a CAC at submit now, so the only thing
          // left on the profile is the UIC, and `unit` is renamed to the
          // thing it was already holding. A PMCS walked before this migration
          // keeps its typed unit string in that column; nothing is lost.
          if (from < 2) {
            await m.alterTable(
              TableMigration(
                profiles,
                columnTransformer: {
                  profiles.uic: const CustomExpression<String>('unit'),
                },
              ),
            );
            await m.renameColumn(pmcsSessions, 'unit', pmcsSessions.uic);
            await m.renameColumn(pmcsReports, 'unit', pmcsReports.uic);
            await m.addColumn(pmcsSessions, pmcsSessions.signatureJson);
            await m.addColumn(pmcsReports, pmcsReports.signatureJson);
          }
          if (from < 3) {
            await transaction(() async {
              // Preserve the local signed copy where one exists, along with
              // the read state of any previously duplicated delivery.
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
              await m.createIndex(pmcsReportsEntityId);
            });
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
