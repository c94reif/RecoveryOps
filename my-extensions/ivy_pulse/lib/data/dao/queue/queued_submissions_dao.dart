import 'package:drift/drift.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/datasources/local/tables/queued_submissions_table.dart';

part 'queued_submissions_dao.g.dart';

@DriftAccessor(tables: [QueuedSubmissions])
class QueuedSubmissionsDao extends DatabaseAccessor<AppDatabase>
    with _$QueuedSubmissionsDaoMixin {
  QueuedSubmissionsDao(super.db);

  /// Oldest first — the queue drains in the order the operator submitted.
  Future<List<QueuedSubmissionData>> getAll() {
    return (select(queuedSubmissions)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> insertRow({
    required String entityId,
    required String bumperNumber,
    required String vehicleType,
    required int redXCount,
    required int faultCount,
    required double latitude,
    required double longitude,
    required String payload,
    required String transport,
    required DateTime createdAt,
  }) async {
    return into(queuedSubmissions).insert(
      QueuedSubmissionsCompanion.insert(
        entityId: entityId,
        bumperNumber: bumperNumber,
        vehicleType: vehicleType,
        redXCount: redXCount,
        faultCount: faultCount,
        latitude: latitude,
        longitude: longitude,
        payload: payload,
        transport: transport,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> deleteById(int id) async {
    await (delete(queuedSubmissions)..where((t) => t.id.equals(id))).go();
  }

  Future<int> count() async {
    final total = queuedSubmissions.id.count();
    final query = selectOnly(queuedSubmissions)..addColumns([total]);
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }
}
