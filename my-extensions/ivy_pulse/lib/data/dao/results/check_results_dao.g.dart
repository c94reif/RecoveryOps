// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_results_dao.dart';

// ignore_for_file: type=lint
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
