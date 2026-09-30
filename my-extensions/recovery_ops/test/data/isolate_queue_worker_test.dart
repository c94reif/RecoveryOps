import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/dao/queue/queued_requests_dao.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/repositories/queued_requests_repo_impl.dart';
import 'package:recovery_ops/data/services/isolate_queue_worker.dart';
import 'package:recovery_ops/data/services/lattice_entity_adapter.dart';
import 'package:recovery_ops/data/services/queue_protocol.dart';
import 'package:recovery_ops/data/services/sdk_mesh_broadcaster.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';
import 'package:recovery_ops/presentation/common/services/queue_prompt_controller.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_snack_bar.dart';

import '../support/queued_request_fixture.dart';
import '../support/sdk_delivery_fakes.dart';

void main() {
  late AppDatabase db;
  late QueuedRequestsRepoImpl repository;
  late RecordingEntityService entities;
  late RecordingMessagingService messaging;
  late QueuePromptController controller;
  late StreamIterator<QueuePromptRequest> prompts;
  late IsolateQueueWorker worker;
  final snackBars = SnackBarService.instance;
  const timeout = Duration(seconds: 5);

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    repository = QueuedRequestsRepoImpl(QueuedRequestsDao(db));
    entities = RecordingEntityService();
    messaging = RecordingMessagingService();
    controller = QueuePromptController.create();
    prompts = StreamIterator(controller.prompts);
    snackBars.queue.clear();
    worker = IsolateQueueWorker(
      repository: repository,
      entityPort: LatticeEntityAdapter(entities: entities),
      meshPort: SdkMeshBroadcaster(messaging: messaging),
      promptStrategy: controller,
    );
  });

  tearDown(() async {
    await worker.stop();
    await prompts.cancel();
    controller.dispose();
    snackBars.queue.clear();
    await db.close();
  });

  Future<void> waitForPendingCount(int count) async {
    await db
        .select(db.queuedRequests)
        .watch()
        .firstWhere((rows) => rows.length == count)
        .timeout(timeout);
  }

  Future<SnackBarData> waitForFeedback(String message) {
    final result = Completer<SnackBarData>();
    void listener() {
      final feedback = snackBars.queue.last;
      if (feedback.message == message && !result.isCompleted) {
        result.complete(feedback);
      }
    }

    snackBars.addListener(listener);
    return result.future.timeout(timeout).whenComplete(
          () => snackBars.removeListener(listener),
        );
  }

  test('persists an offline request before notifying the worker or operator',
      () async {
    final receiver = ReceivePort();
    addTearDown(receiver.close);
    worker.toWorker = receiver.sendPort;
    final wire = receiver.first;
    await worker.enqueue(queuedRequest(transport: TransportKind.mesh));

    final stored = (await repository.getAll()).single;
    expect(await wire.timeout(timeout), mainEnqueue(stored.toMap()));
    expect(stored.id, isNotNull);
    expect(snackBars.queue.single.message, contains('Mesh unreachable'));
    expect(snackBars.queue.single.isError, isTrue);
    expect(messaging.broadcasts, isEmpty);
  });

  test(
      'resumes saved requests, asks permission, then deletes only after delivery',
      () async {
    final stored = await repository.insert(queuedRequest());
    await worker.start();
    final isolate = worker.isolate;
    await worker.start();
    expect(worker.isolate, same(isolate));

    final next = prompts.moveNext();
    worker.reportTransportOutcome(
        transport: TransportKind.lattice, success: true);
    expect(await next.timeout(timeout), isTrue);
    expect(prompts.current.request.toMap(), stored.toMap());
    expect(entities.upserts, isEmpty);
    expect(await repository.getAll(), hasLength(1));

    prompts.current.respond(true);
    await waitForPendingCount(0);
    expect(entities.upserts.single.id, stored.entityId);
    expect(messaging.broadcasts, isEmpty);
    expect(snackBars.queue.last.message, 'Lattice: sent (queued)');
    expect(snackBars.queue.last.isError, isFalse);

    await worker.stop();
    await worker.stop();
    expect(worker.isolate, isNull);
    expect(worker.toWorker, isNull);
    expect(worker.fromWorker, isNull);
    expect(worker.readyCompleter, isNull);
    await worker.start();
    expect(worker.isolate, isNotNull);
    expect(worker.isolate, isNot(same(isolate)));
  });

  test('discarding a mesh request never sends it or deletes the lattice copy',
      () async {
    final lattice = await repository.insert(queuedRequest());
    final mesh = await repository.insert(
      queuedRequest(transport: TransportKind.mesh),
    );
    await worker.start();

    final next = prompts.moveNext();
    worker.reportTransportOutcome(transport: TransportKind.mesh, success: true);
    expect(await next.timeout(timeout), isTrue);
    expect(prompts.current.request.id, mesh.id);
    prompts.current.respond(false);
    await waitForPendingCount(1);

    expect((await repository.getAll()).single.toMap(), lattice.toMap());
    expect(messaging.broadcasts, isEmpty);
    expect(entities.upserts, isEmpty);
  });

  test('a failed retry stays on disk and is offered again after reconnecting',
      () async {
    final stored = await repository.insert(
      queuedRequest(transport: TransportKind.mesh),
    );
    messaging.results = [];
    await worker.start();

    var next = prompts.moveNext();
    worker.reportTransportOutcome(transport: TransportKind.mesh, success: true);
    expect(await next.timeout(timeout), isTrue);
    final failed = waitForFeedback('Mesh: still FAILED');
    prompts.current.respond(true);
    expect((await failed).isError, isTrue);
    expect((await repository.getAll()).single.toMap(), stored.toMap());

    messaging.results = RecordingMessagingService().results;
    next = prompts.moveNext();
    worker.reportTransportOutcome(transport: TransportKind.mesh, success: true);
    expect(await next.timeout(timeout), isTrue);
    expect(prompts.current.request.id, stored.id);
    prompts.current.respond(true);
    await waitForPendingCount(0);
    expect(messaging.broadcasts, hasLength(2));
    for (final payload in messaging.broadcasts) {
      final body = jsonDecode(payload) as Map<String, dynamic>;
      expect(body['entityId'], stored.entityId);
      expect(body['bumperNumber'], stored.bumperNumber);
      expect(body['latitude'], stored.latitude);
      expect(body['longitude'], stored.longitude);
    }
  });

  test('reports unsuccessful lattice execution without deleting the stored row',
      () async {
    entities.failWrite = true;
    final stored = await repository.insert(queuedRequest());
    final receiver = ReceivePort();
    addTearDown(receiver.close);
    worker.toWorker = receiver.sendPort;
    final outcome = receiver.first;

    await worker.handleExecute(stored.id!, stored);
    expect(await outcome.timeout(timeout),
        mainExecuteResult(requestId: stored.id!, success: false));
    expect(await repository.getAll(), hasLength(1));
    expect(snackBars.queue.last.isError, isTrue);
  });

  test('unexpected worker messages do not delete or publish pending requests',
      () async {
    final stored = await repository.insert(queuedRequest());
    worker.handleWorkerMessage('malformed');
    worker.handleWorkerMessage({'type': 'unknown'});
    worker.handleWorkerMessage(workerLog('diagnostic'));
    expect((await repository.getAll()).single.toMap(), stored.toMap());
    expect(entities.upserts, isEmpty);
    expect(messaging.broadcasts, isEmpty);
  });
}
