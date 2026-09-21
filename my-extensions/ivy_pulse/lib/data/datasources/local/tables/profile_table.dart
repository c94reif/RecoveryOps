import 'package:drift/drift.dart';

@DataClassName('ProfileData')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unit Identification Code. The only thing the profile holds — the
  /// operator's identity comes off their CAC when the PMCS is closed out.
  TextColumn get uic => text()();
}
