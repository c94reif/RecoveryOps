import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/isolate_queue_worker.dart';
import 'package:ivy_pulse/data/services/main_thread_queue_worker.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/usecases/map/show_report_on_map.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../support/fakes.dart';
import '../view_model/reports_view_model_test.dart'
    show FakeMessagingService, FakeMapService;
import 'main_thread_queue_worker_test.dart' show FakeQueuePromptStrategy;

class GatedSource extends FakeRemoteReportSource {
  Completer<List<PmcsReport>>? remoteGate;
  Completer<Set<String>>? knownGate;
  int remoteCalls = 0;
  @override
  Future<List<PmcsReport>> fetchRemotePmcsReports() async {
    remoteCalls++;
    return remoteGate == null
        ? super.fetchRemotePmcsReports()
        : remoteGate!.future;
  }

  @override
  Future<Set<String>> fetchKnownPmcsEntityIds() =>
      knownGate?.future ?? super.fetchKnownPmcsEntityIds();
}

void main() {
  late DeliveryCoordinator delivery;
  late FakeQueuedSubmissionsRepository queue;
  late FakePmcsEntityPort entity;
  late FakeMeshBroadcaster mesh;
  late GatedSource source;
  late MainThreadQueueWorker worker;

  setUp(() {
    delivery = DeliveryCoordinator();
    queue = FakeQueuedSubmissionsRepository();
    entity = FakePmcsEntityPort();
    mesh = FakeMeshBroadcaster();
    source = GatedSource();
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: entity,
        meshPort: mesh,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery);
  });
  tearDown(() async {
    await worker.stop();
    await delivery.dispose();
  });

  test('overlapping publishes send once per transport and show each completion',
      () async {
    final gate = Completer<bool>();
    entity.publishGate = gate;
    final publish = PublishPmcsReport(
        entityPort: entity,
        meshPort: mesh,
        queueWorker: worker,
        codec: FakeReportCodec(),
        clock: FixedClock(DateTime.utc(2026)),
        delivery: delivery);
    final first = publish(buildReport());
    final second = publish(buildReport());
    await Future<void>.delayed(Duration.zero);
    expect(entity.published, hasLength(1));
    expect(mesh.broadcast, hasLength(1));
    expect(
        delivery.status('session-1', TransportKind.mesh), DeliveryStatus.sent);
    expect(delivery.status('session-1', TransportKind.lattice),
        DeliveryStatus.sending);
    gate.complete(false);
    await Future.wait([first, second]);
    expect(queue.submissions, hasLength(1));
    expect(delivery.status('session-1', TransportKind.lattice),
        DeliveryStatus.queued);
  });

  test('a fresh submission joining a failed repair still persists its retry',
      () async {
    final gate = Completer<bool>();
    entity.publishGate = gate;
    final repair = SyncLocalReportsToLattice(source, entity,
        delivery: delivery, queuedRepository: queue)([buildReport()]);
    await Future<void>.delayed(Duration.zero);
    final publish = PublishPmcsReport(
        entityPort: entity,
        meshPort: mesh,
        queueWorker: worker,
        codec: FakeReportCodec(),
        clock: FixedClock(DateTime.utc(2026)),
        delivery: delivery);
    final submission = publish(buildReport());
    gate.complete(false);
    await repair;
    await submission;
    expect(entity.published, hasLength(1));
    expect(queue.submissions, hasLength(1));
    expect(delivery.status('session-1', TransportKind.lattice),
        DeliveryStatus.queued);
  });

  test('repair leaves queued reports to their retry worker', () async {
    await queue.insert(buildQueuedSubmission());
    final sync = SyncLocalReportsToLattice(source, entity,
        delivery: delivery, queuedRepository: queue);
    expect(await sync([buildReport()]), 0);
    expect(entity.published, isEmpty);
  });

  test('a stale refresh snapshot does not resend a successful queue retry',
      () async {
    await worker.enqueue(buildQueuedSubmission());
    source.knownGate = Completer<Set<String>>();
    final sync = SyncLocalReportsToLattice(source, entity,
        delivery: delivery, queuedRepository: queue);
    final refresh = sync([buildReport()]);
    await worker.nudge(TransportKind.lattice);
    expect(queue.submissions, isEmpty);
    source.knownGate!.complete({});
    expect(await refresh, 0);
    expect(entity.published, isEmpty);
    expect(entity.publishedPayloads, hasLength(1));
  });

  test('refresh callers join one sync and queue changes update the list live',
      () async {
    final messaging = FakeMessagingService();
    final reports = FakeReportsRepository();
    final codec = FakeReportCodec();
    final model = ReportsViewModel(
      messaging,
      reports,
      ParseIncomingReport(codec),
      ParseIncomingDeletion(codec),
      SyncRemoteReports(source, reports),
      SyncLocalReportsToLattice(source, entity,
          delivery: delivery, queuedRepository: queue),
      ShowReportOnMap(FakeMapService()),
      PublishPmcsDeletion(entityPort: entity, meshPort: mesh),
      worker,
      profileRepository: FakeProfileRepository(),
      queuedRepository: queue,
      delivery: delivery,
    );
    addTearDown(model.dispose);
    addTearDown(messaging.close);
    await Future<void>.delayed(Duration.zero);
    source.remoteGate = Completer<List<PmcsReport>>();
    final refresh = model.syncRemoteLatticeReports();
    final repeat = model.syncRemoteLatticeReports();
    expect(identical(refresh, repeat), isTrue);
    expect(source.remoteCalls, 1);
    source.remoteGate!.complete([]);
    await Future.wait([refresh, repeat]);
    await worker.enqueue(buildQueuedSubmission());
    await Future<void>.delayed(Duration.zero);
    expect(model.queuedCount.value, 1);
    expect(model.queued, hasLength(1));
    await worker.nudge(TransportKind.lattice);
    await Future<void>.delayed(Duration.zero);
    expect(model.queuedCount.value, 0);
    expect(model.queued, isEmpty);
  });

  test('native worker retries automatically and reports successful delivery',
      () async {
    final native = IsolateQueueWorker(
        repository: queue,
        entityPort: entity,
        meshPort: mesh,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery,
        probeInterval: const Duration(milliseconds: 10));
    addTearDown(native.stop);
    final sent = Completer<void>();
    final subscription = delivery.changes.listen((_) {
      if (delivery.status('session-1', TransportKind.lattice) ==
              DeliveryStatus.sent &&
          queue.submissions.isEmpty &&
          !sent.isCompleted) {
        sent.complete();
      }
    });
    addTearDown(subscription.cancel);
    await native.start();
    await native.enqueue(buildQueuedSubmission());
    await sent.future.timeout(const Duration(seconds: 3));
    expect(entity.publishedPayloads, hasLength(1));
    expect(queue.submissions, isEmpty);
  });
}
