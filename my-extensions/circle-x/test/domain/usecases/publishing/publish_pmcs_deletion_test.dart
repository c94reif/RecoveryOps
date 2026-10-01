import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_deletion.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late PublishPmcsDeletion usecase;

  setUp(() {
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    usecase = PublishPmcsDeletion(
        codec: const PmcsReportCodec(),
        entityPort: entityPort,
        meshPort: meshPort,
        queueWorker: FakeQueueWorker(),
        repository: FakeReportsRepository(),
        delivery: DeliveryCoordinator(),
        queuedRepository: FakeQueuedSubmissionsRepository(),
        transaction: FakeTransactionRunner());
  });

  test('withdraws from both transports', () async {
    final outcome = await usecase(buildReport(entityId: 'entity-1'));

    expect(outcome.allSucceeded, isTrue);
    expect(entityPort.deletedIds, ['entity-1']);
    expect(meshPort.deletedIds, ['entity-1']);
  });

  test('one transport failing does not stop the other', () async {
    entityPort.deleteSucceeds = false;

    final outcome = await usecase(buildReport(entityId: 'entity-1'));

    expect(outcome.latticeOk, isFalse);
    expect(outcome.meshOk, isTrue);
    expect(meshPort.deletedIds, ['entity-1']);
  });
}
