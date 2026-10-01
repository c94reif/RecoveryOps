// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PmcsSessionsTable get pmcsSessions => attachedDatabase.pmcsSessions;
  SessionsDaoManager get managers => SessionsDaoManager(this);
}

class SessionsDaoManager {
  final _$SessionsDaoMixin _db;
  SessionsDaoManager(this._db);
  $$PmcsSessionsTableTableManager get pmcsSessions =>
      $$PmcsSessionsTableTableManager(_db.attachedDatabase, _db.pmcsSessions);
}
