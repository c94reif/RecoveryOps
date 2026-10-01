import 'package:drift/drift.dart';

@DataClassName('CheckResultData')
class CheckResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get phase => text()();
  TextColumn get itemId => text()();
  IntColumn get faultIndex => integer()();
  TextColumn get faultLabel => text()();

  TextColumn get severity => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {sessionId, phase, itemId},
      ];
}
