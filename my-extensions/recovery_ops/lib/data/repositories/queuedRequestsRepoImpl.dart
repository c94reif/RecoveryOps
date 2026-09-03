import 'package:recovery_ops/data/dao/queue/queuedRequestsDao.dart';
import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';
import 'package:recovery_ops/domain/repositories/queuedRequestsRepo.dart';

class QueuedRequestsRepoImpl implements QueuedRequestsRepository {
  final QueuedRequestsDao dao;

  QueuedRequestsRepoImpl(this.dao);

  @override
  Future<List<QueuedRequest>> getAll() async {
    final rows = await dao.getAll();
    return rows
        .map((r) => QueuedRequest(
              id: r.id,
              entityId: r.entityId,
              bumperNumber: r.bumperNumber,
              issue: r.issue,
              recoveryType: r.recoveryType,
              latitude: r.latitude,
              longitude: r.longitude,
              transport: TransportKind.fromWireName(r.transport),
              createdAt: r.createdAt,
            ))
        .toList();
  }

  @override
  Future<QueuedRequest> insert(QueuedRequest request) async {
    final id = await dao.insertRow(
      entityId: request.entityId,
      bumperNumber: request.bumperNumber,
      issue: request.issue,
      recoveryType: request.recoveryType,
      latitude: request.latitude,
      longitude: request.longitude,
      transport: request.transport.wireName,
      createdAt: request.createdAt,
    );
    return request.copyWith(id: id);
  }

  @override
  Future<void> deleteById(int id) => dao.deleteById(id);
}
