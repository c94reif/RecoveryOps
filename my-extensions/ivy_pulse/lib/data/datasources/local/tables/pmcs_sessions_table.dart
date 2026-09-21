import 'package:drift/drift.dart';

@DataClassName('PmcsSessionData')
class PmcsSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// UUID the results, faults and published entity all hang off of.
  TextColumn get sessionId => text().unique()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();
  TextColumn get operator => text()();

  /// Unit Identification Code, carried from the profile.
  TextColumn get uic => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get submittedAt => dateTime().nullable()();

  /// Comma-joined phase wire names; empty until the first phase is closed.
  TextColumn get completedPhases => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('IN_PROGRESS'))();

  /// `PmcsSignature.toMap()` as JSON — who closed this PMCS out and whether
  /// a CAC backed it up. Null until the session is submitted.
  TextColumn get signatureJson => text().nullable()();

  /// Where the walk-around started. Nullable — the host location bridge is
  /// allowed to be unavailable rather than block a PMCS.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}
