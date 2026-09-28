part of 'check_results_dao.dart';

mixin _$CheckResultsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CheckResultsTable get checkResults => attachedDatabase.checkResults;
  CheckResultsDaoManager get managers => CheckResultsDaoManager(this);
}

class CheckResultsDaoManager {
  final _$CheckResultsDaoMixin _db;
  CheckResultsDaoManager(this._db);
  $$CheckResultsTableTableManager get checkResults =>
      $$CheckResultsTableTableManager(_db.attachedDatabase, _db.checkResults);
}
