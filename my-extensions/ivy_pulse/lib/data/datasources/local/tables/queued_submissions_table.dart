import 'package:drift/drift.dart';

/// One row per transport leg that refused a submission, so Lattice being down
/// never holds up the mesh copy and vice versa.
@DataClassName('QueuedSubmissionData')
class QueuedSubmissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();

  /// Denormalised counts so the queue screen can describe what is parked
  /// without decoding [payload].
  IntColumn get redXCount => integer()();
  IntColumn get faultCount => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// The already-encoded report body — a retry must send what was approved,
  /// not whatever the session has since been edited into.
  TextColumn get payload => text()();
  TextColumn get transport => text()();
  DateTimeColumn get createdAt => dateTime()();
}
