import 'package:drift/drift.dart';

@DataClassName('PmcsReportData')
class PmcsReports extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Shared with the Lattice entity and the mesh payload, so the same PMCS
  /// arriving on both transports lands as one report.
  TextColumn get entityId => text()();
  TextColumn get fromCallsign => text()();
  TextColumn get bumperNumber => text()();
  TextColumn get vehicleType => text()();
  TextColumn get operator => text()();

  /// Unit Identification Code, carried from the profile.
  TextColumn get uic => text()();

  /// Comma-joined phase wire names covered by this submission.
  TextColumn get phases => text()();

  /// JSON list of `PmcsFault.toMap()` — the fault detail travels with the
  /// report so a receiving crew never needs the sender's session rows.
  TextColumn get faultsJson => text()();

  /// `PmcsSignature.toMap()` as JSON — who signed it off and whether a CAC
  /// backed it up. Null on a report from a build that predates verification.
  TextColumn get signatureJson => text().nullable()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isOutgoing => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
}
