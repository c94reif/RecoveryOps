import 'package:drift/drift.dart';

/// Faults are denormalised from the catalog on purpose: a 5988-E handed to a
/// maintainer has to read the same months later even if the TM catalog the
/// extension ships has moved on.
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
