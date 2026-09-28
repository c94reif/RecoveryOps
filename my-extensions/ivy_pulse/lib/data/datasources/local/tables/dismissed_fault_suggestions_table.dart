import 'package:drift/drift.dart';

class DismissedFaultSuggestions extends Table {
  TextColumn get suggestionId => text()();

  @override
  Set<Column> get primaryKey => {suggestionId};
}
