part of 'sessions_dao.dart';

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
