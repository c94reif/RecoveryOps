import 'package:drift/drift.dart';

@DataClassName('ProfileData')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uic => text()();
}
