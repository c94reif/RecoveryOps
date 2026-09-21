import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';

class QueuedSubmissionsRepoImpl implements QueuedSubmissionsRepository {
  final QueuedSubmissionsDao dao;

  QueuedSubmissionsRepoImpl(this.dao);

  @override
  Future<List<QueuedSubmission>> getAll() async {
    final rows = await dao.getAll();
    final parked = rows.map(toEntity).whereType<QueuedSubmission>().toList();
    if (parked.length != rows.length) {
      debugPrint('[IvyPulse] getAll: skipped '
          '${rows.length - parked.length} queued row(s) on an unknown '
          'transport');
    }
    return parked;
  }

  @override
  Future<QueuedSubmission> insert(QueuedSubmission submission) async {
    final id = await dao.insertRow(
      entityId: submission.entityId,
      bumperNumber: submission.bumperNumber,
      vehicleType: submission.vehicleType,
      redXCount: submission.redXCount,
      faultCount: submission.faultCount,
      latitude: submission.latitude,
      longitude: submission.longitude,
      payload: submission.payload,
      transport: submission.transport.wireName,
      createdAt: submission.createdAt,
    );
    return submission.copyWith(id: id);
  }

  @override
  Future<void> deleteById(int id) => dao.deleteById(id);

  /// Null when the row names a transport this build cannot send on. It is left
  /// on disk rather than dropped, but skipped here: one unreadable row must not
  /// throw on start-up and strand every other PMCS still parked on the queue.
  static QueuedSubmission? toEntity(QueuedSubmissionData row) {
    final transport = TransportKind.tryFromWireName(row.transport);
    if (transport == null) return null;

    return QueuedSubmission(
      id: row.id,
      entityId: row.entityId,
      bumperNumber: row.bumperNumber,
      vehicleType: row.vehicleType,
      redXCount: row.redXCount,
      faultCount: row.faultCount,
      latitude: row.latitude,
      longitude: row.longitude,
      payload: row.payload,
      transport: transport,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<int> count() => dao.count();
}
