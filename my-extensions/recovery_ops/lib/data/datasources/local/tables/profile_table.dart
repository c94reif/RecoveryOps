import 'package:drift/drift.dart';

@DataClassName('ProfileData')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get callSign => text()();
  TextColumn get unit => text()();
}
