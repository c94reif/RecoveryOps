import 'package:drift/drift.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/datasources/local/tables/queuedRequestsTable.dart';

part 'queuedRequestsDao.g.dart';

@DriftAccessor(tables: [QueuedRequests])
class QueuedRequestsDao extends DatabaseAccessor<AppDatabase>
    with _$QueuedRequestsDaoMixin {
  QueuedRequestsDao(super.db);

  Future<List<QueuedRequestData>> getAll() {
    return (select(queuedRequests)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> insertRow({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
    required String transport,
    required DateTime createdAt,
  }) async {
    return into(queuedRequests).insert(
      QueuedRequestsCompanion.insert(
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        recoveryType: recoveryType,
        latitude: latitude,
        longitude: longitude,
        transport: transport,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> deleteById(int id) async {
    await (delete(queuedRequests)..where((t) => t.id.equals(id))).go();
  }
}
