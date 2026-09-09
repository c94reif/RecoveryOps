import 'package:drift/drift.dart';

@DataClassName('ReportData')
class Reports extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text().nullable()();
  TextColumn get fromCallsign => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get issue => text()();
  TextColumn get recoveryType => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get navigatorLatitude => real().nullable()();
  RealColumn get navigatorLongitude => real().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get routeGeometry => text().nullable()();
  BoolColumn get isOutgoing => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
}
