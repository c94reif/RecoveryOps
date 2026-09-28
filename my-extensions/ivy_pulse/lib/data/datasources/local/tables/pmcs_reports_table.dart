import 'package:drift/drift.dart';

@TableIndex.sql(
    "CREATE UNIQUE INDEX pmcs_reports_entity_id ON pmcs_reports (entity_id) WHERE entity_id <> ''")
@DataClassName('PmcsReportData')
class PmcsReports extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get entityId => text()();
  TextColumn get fromCallsign => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();
  TextColumn get operator => text()();

  TextColumn get uic => text()();

  TextColumn get phases => text()();

  TextColumn get faultsJson => text()();

  TextColumn get signatureJson => text().nullable()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isOutgoing => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
}
