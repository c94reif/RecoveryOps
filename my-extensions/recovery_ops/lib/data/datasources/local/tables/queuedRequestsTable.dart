import 'package:drift/drift.dart';

@DataClassName('QueuedRequestData')
class QueuedRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get issue => text()();
  TextColumn get recoveryType => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get transport => text()();
  DateTimeColumn get createdAt => dateTime()();
}
