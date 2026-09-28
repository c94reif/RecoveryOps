import 'package:drift/drift.dart';

class ReportWithdrawals extends Table {
  TextColumn get entityId => text()();

  @override
  Set<Column> get primaryKey => {entityId};
}
