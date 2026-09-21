import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late PublishPmcsDeletion usecase;

  setUp(() {
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    usecase = PublishPmcsDeletion(entityPort: entityPort, meshPort: meshPort);
  });

  test('withdraws from both transports', () async {
    final outcome = await usecase(entityId: 'entity-1');

    expect(outcome.allSucceeded, isTrue);
    expect(entityPort.deletedIds, ['entity-1']);
    expect(meshPort.deletedIds, ['entity-1']);
  });

  test('one transport failing does not stop the other', () async {
    entityPort.deleteSucceeds = false;

    final outcome = await usecase(entityId: 'entity-1');

    expect(outcome.latticeOk, isFalse);
    expect(outcome.meshOk, isTrue);
    expect(meshPort.deletedIds, ['entity-1']);
  });
}
