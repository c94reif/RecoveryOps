import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late FakeQueueWorker queueWorker;
  late FakeReportCodec codec;
  late PublishPmcsReport usecase;

  setUp(() {
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    queueWorker = FakeQueueWorker();
    codec = FakeReportCodec();
    usecase = PublishPmcsReport(
      entityPort: entityPort,
      meshPort: meshPort,
      queueWorker: queueWorker,
      codec: codec,
      clock: FixedClock(DateTime.utc(2026, 3, 24, 9)),
    );
  });

  test('sends on both transports', () async {
    final outcome = await usecase(buildReport());

    expect(outcome.latticeOk, isTrue);
    expect(outcome.meshOk, isTrue);
    expect(outcome.allSucceeded, isTrue);
    expect(entityPort.published, hasLength(1));
    expect(meshPort.broadcast, hasLength(1));
  });

  test('nothing is queued when both legs succeed', () async {
    await usecase(buildReport());

    expect(queueWorker.enqueued, isEmpty);
  });

  test('a failed Lattice leg queues only that leg', () async {
    entityPort.publishSucceeds = false;

    final outcome = await usecase(buildReport());

    expect(outcome.latticeOk, isFalse);
    expect(outcome.meshOk, isTrue);
    expect(queueWorker.enqueued, hasLength(1));
    expect(queueWorker.enqueued.single.transport, TransportKind.lattice);
  });

  test('a failed mesh leg queues only that leg', () async {
    meshPort.broadcastSucceeds = false;

    await usecase(buildReport());

    expect(queueWorker.enqueued.single.transport, TransportKind.mesh);
  });

  test('both legs down queues both copies', () async {
    entityPort.publishSucceeds = false;
    meshPort.broadcastSucceeds = false;

    final outcome = await usecase(buildReport());

    expect(outcome.allFailed, isTrue);
    expect(
      queueWorker.enqueued.map((s) => s.transport).toSet(),
      {TransportKind.lattice, TransportKind.mesh},
    );
  });

  test('every leg outcome is reported to the queue worker', () async {
    entityPort.publishSucceeds = false;

    await usecase(buildReport());

    expect(queueWorker.outcomes, contains((TransportKind.lattice, false)));
    expect(queueWorker.outcomes, contains((TransportKind.mesh, true)));
  });

  test('the report is encoded once and the payload reused for both legs',
      () async {
    entityPort.publishSucceeds = false;
    meshPort.broadcastSucceeds = false;

    await usecase(buildReport(entityId: 'abc'));

    expect(codec.encoded, hasLength(1));
    for (final submission in queueWorker.enqueued) {
      expect(submission.payload, 'encoded:abc');
    }
  });

  test('the queued copy carries the fault counts a maintainer needs', () async {
    entityPort.publishSucceeds = false;

    await usecase(buildReport(faults: [
      buildFault(itemId: 'a', severity: FaultSeverity.redX),
      buildFault(itemId: 'b', severity: FaultSeverity.circleX),
      buildFault(itemId: 'c', severity: FaultSeverity.dash),
    ]));

    final queued = queueWorker.enqueued.single;
    expect(queued.faultCount, 3);
    expect(queued.redXCount, 1);
    expect(queued.bumperNumber, 'A-11');
    expect(queued.createdAt, DateTime.utc(2026, 3, 24, 9));
  });

  test('the queued copy keeps the vehicle position for the map', () async {
    meshPort.broadcastSucceeds = false;

    await usecase(buildReport());

    final queued = queueWorker.enqueued.single;
    expect(queued.latitude, 33.0);
    expect(queued.longitude, -84.0);
  });
}
