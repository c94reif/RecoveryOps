// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_submissions_dao.dart';

// ignore_for_file: type=lint
mixin _$QueuedSubmissionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $QueuedSubmissionsTable get queuedSubmissions =>
      attachedDatabase.queuedSubmissions;
  QueuedSubmissionsDaoManager get managers => QueuedSubmissionsDaoManager(this);
}

class QueuedSubmissionsDaoManager {
  final _$QueuedSubmissionsDaoMixin _db;
  QueuedSubmissionsDaoManager(this._db);
  $$QueuedSubmissionsTableTableManager get queuedSubmissions =>
      $$QueuedSubmissionsTableTableManager(
          _db.attachedDatabase, _db.queuedSubmissions);
}
