import 'package:drift/drift.dart';

@DataClassName('CheckResultData')
class CheckResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get phase => text()();
  TextColumn get itemId => text()();
  IntColumn get faultIndex => integer()();
  TextColumn get faultLabel => text()();

  /// Null when the check came back serviceable — no fault, no symbol.
  TextColumn get severity => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  /// An operator who changes their mind about a check must end up with one
  /// answer, not two — the second tap has to overwrite the first.
  @override
  List<Set<Column>> get uniqueKeys => [
        {sessionId, phase, itemId},
      ];
}
