part of 'queued_submissions_dao.dart';

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
