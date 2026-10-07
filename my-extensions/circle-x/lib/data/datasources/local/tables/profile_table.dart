import 'package:drift/drift.dart';

@DataClassName('ProfileData')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uic => text()();

  TextColumn get unitName => text().withDefault(const Constant(''))();

  TextColumn get followedUnitsJson =>
      text().withDefault(const Constant('[]'))();
}
