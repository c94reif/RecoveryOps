// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_requests_dao.dart';

// ignore_for_file: type=lint
mixin _$QueuedRequestsDaoMixin on DatabaseAccessor<AppDatabase> {
  $QueuedRequestsTable get queuedRequests => attachedDatabase.queuedRequests;
  QueuedRequestsDaoManager get managers => QueuedRequestsDaoManager(this);
}

class QueuedRequestsDaoManager {
  final _$QueuedRequestsDaoMixin _db;
  QueuedRequestsDaoManager(this._db);
  $$QueuedRequestsTableTableManager get queuedRequests =>
      $$QueuedRequestsTableTableManager(
          _db.attachedDatabase, _db.queuedRequests);
}
