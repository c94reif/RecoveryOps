import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:recovery_ops/data/datasources/local/tables/profileTable.dart';
import 'package:recovery_ops/data/datasources/local/tables/queuedRequestsTable.dart';
import 'package:recovery_ops/data/datasources/local/tables/reportsTable.dart';
import 'package:recovery_ops/data/dao/profile/profileDao.dart';
import 'package:recovery_ops/data/dao/queue/queuedRequestsDao.dart';
import 'package:recovery_ops/data/dao/reports/reportsDao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Profiles, Reports, QueuedRequests],
  daos: [ProfileDao, ReportsDao, QueuedRequestsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(reports);
          }
          if (from < 3) {
            await m.addColumn(reports, reports.entityId);
            await m.addColumn(reports, reports.navigatorLatitude);
            await m.addColumn(reports, reports.navigatorLongitude);
          }
          if (from < 4) {
            await m.addColumn(reports, reports.routeGeometry);
          }
          if (from < 5) {
            await m.createTable(queuedRequests);
          }
        },
      );
}

QueryExecutor openConnection() {
  return driftDatabase(
    name: 'recovery_ops_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
