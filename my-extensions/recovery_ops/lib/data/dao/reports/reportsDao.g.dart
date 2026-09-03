// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reportsDao.dart';

// ignore_for_file: type=lint
mixin _$ReportsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReportsTable get reports => attachedDatabase.reports;
  ReportsDaoManager get managers => ReportsDaoManager(this);
}

class ReportsDaoManager {
  final _$ReportsDaoMixin _db;
  ReportsDaoManager(this._db);
  $$ReportsTableTableManager get reports =>
      $$ReportsTableTableManager(_db.attachedDatabase, _db.reports);
}
