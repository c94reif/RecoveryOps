import 'package:drift/drift.dart';

@DataClassName('PmcsSessionData')
class PmcsSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sessionId => text().unique()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();
  TextColumn get operator => text()();

  TextColumn get uic => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get submittedAt => dateTime().nullable()();

  TextColumn get completedPhases => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('IN_PROGRESS'))();

  TextColumn get signatureJson => text().nullable()();

  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}
