import 'package:drift/drift.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/datasources/local/tables/queued_submissions_table.dart';

part 'queued_submissions_dao.g.dart';

@DriftAccessor(tables: [QueuedSubmissions])
class QueuedSubmissionsDao extends DatabaseAccessor<AppDatabase>
    with _$QueuedSubmissionsDaoMixin {
  QueuedSubmissionsDao(super.db);

  Future<List<QueuedSubmissionData>> getAll() {
    return (select(queuedSubmissions)
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
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
    await (delete(queuedSubmissions)..where((table) => table.id.equals(id)))
        .go();
  }

  Future<int> count() async {
    final total = queuedSubmissions.id.count();
    final query = selectOnly(queuedSubmissions)..addColumns([total]);
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }
}
