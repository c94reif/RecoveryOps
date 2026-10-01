import 'package:drift/drift.dart';

@DataClassName('QueuedSubmissionData')
class QueuedSubmissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();

  IntColumn get redXCount => integer()();
  IntColumn get faultCount => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  TextColumn get payload => text()();
  TextColumn get transport => text()();
  DateTimeColumn get createdAt => dateTime()();
}
