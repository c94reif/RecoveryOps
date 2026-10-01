// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pmcs_reports_dao.dart';

// ignore_for_file: type=lint
mixin _$PmcsReportsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PmcsReportsTable get pmcsReports => attachedDatabase.pmcsReports;
  PmcsReportsDaoManager get managers => PmcsReportsDaoManager(this);
}

class PmcsReportsDaoManager {
  final _$PmcsReportsDaoMixin _db;
  PmcsReportsDaoManager(this._db);
  $$PmcsReportsTableTableManager get pmcsReports =>
      $$PmcsReportsTableTableManager(_db.attachedDatabase, _db.pmcsReports);
}
