import 'package:drift/drift.dart';

@DataClassName('PmcsFaultData')
class PmcsFaults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get itemId => text()();
  TextColumn get phase => text()();
  TextColumn get category => text()();
  TextColumn get subcategory => text()();
  TextColumn get description => text()();
  TextColumn get condition => text()();
  TextColumn get severity => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
}
