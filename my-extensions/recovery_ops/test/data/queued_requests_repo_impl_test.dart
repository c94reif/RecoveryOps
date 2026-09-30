import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/dao/queue/queued_requests_dao.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/repositories/queued_requests_repo_impl.dart';
import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';

import '../support/queued_request_fixture.dart';

void main() {
  late AppDatabase db;
  late QueuedRequestsRepoImpl repository;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    repository = QueuedRequestsRepoImpl(QueuedRequestsDao(db));
  });

  tearDown(() => db.close());

  test('a new queue has no pending deliveries', () async {
    expect(await repository.getAll(), isEmpty);
  });

  test('persists both delivery legs with their full retry payload', () async {
    for (final transport in TransportKind.values) {
      final request = queuedRequest(transport: transport);
      final stored = await repository.insert(request);
      expect(stored.id, isNotNull);
      expect(request.id, isNull);
      expect(stored.copyWith().toMap(), stored.toMap());
      final readBack = (await repository.getAll()).last;
      expect(readBack.toMap(), stored.toMap());
      expect(readBack.summary, 'HQ-42 - Wrecker');
    }
    final rows = await repository.getAll();
    expect(rows.map((row) => row.id).toSet(), hasLength(2));
  });

  test('retries oldest first even when inserts arrive out of order', () async {
    await repository.insert(queuedRequest(
      entityId: 'newer',
      createdAt: DateTime.utc(2026, 4, 11),
    ));
    await repository.insert(queuedRequest(entityId: 'older'));

    expect((await repository.getAll()).map((row) => row.entityId),
        ['older', 'newer']);
  });

  test('deleting one delivery leaves the other transport queued', () async {
    final lattice = await repository.insert(queuedRequest());
    final mesh = await repository.insert(
      queuedRequest(transport: TransportKind.mesh),
    );
    await repository.deleteById(lattice.id!);
    await repository.deleteById(lattice.id!);
    await repository.deleteById(9999);

    expect((await repository.getAll()).single.toMap(), mesh.toMap());
  });

  test('isolate messages preserve payloads and normalize timestamps to UTC',
      () {
    final request = queuedRequest(id: 7, transport: TransportKind.mesh);
    final wire = request.toMap()
      ..['latitude'] = 33
      ..['createdAt'] = '2026-04-10T11:00:00+02:00';
    final decoded = QueuedRequest.fromMap(wire);

    expect(decoded.id, 7);
    expect(decoded.latitude, 33.0);
    expect(decoded.transport, TransportKind.mesh);
    expect(decoded.createdAt, DateTime.utc(2026, 4, 10, 9));
    expect(decoded.createdAt.isUtc, isTrue);
    expect(decoded.toMap()['createdAt'], '2026-04-10T09:00:00.000Z');
    expect(QueuedRequest.fromMap(request.toMap()).toMap(), request.toMap());
  });

  test('an unknown transport is rejected instead of sent on the wrong leg', () {
    final wire = queuedRequest().toMap()..['transport'] = 'unknown';
    expect(() => QueuedRequest.fromMap(wire), throwsArgumentError);
  });
}
