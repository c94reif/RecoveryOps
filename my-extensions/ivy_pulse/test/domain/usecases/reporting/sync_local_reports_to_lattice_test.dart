import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemoteReportSource source;
  late FakePmcsEntityPort entityPort;
  late SyncLocalReportsToLattice usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    entityPort = FakePmcsEntityPort();
    usecase = SyncLocalReportsToLattice(source, entityPort);
  });

  test('re-publishes our reports the host never received', () async {
    source.knownIds = {};

    final count = await usecase([buildReport(entityId: 'mine-1')]);

    expect(count, 1);
    expect(entityPort.published.single.entityId, 'mine-1');
  });

  test('leaves reports the host already has alone', () async {
    source.knownIds = {'mine-1'};

    expect(await usecase([buildReport(entityId: 'mine-1')]), 0);
    expect(entityPort.published, isEmpty);
  });

  test('ignores reports received from other crews', () async {
    final count = await usecase([
      buildReport(entityId: 'theirs-1', isOutgoing: false),
    ]);

    expect(count, 0);
    expect(entityPort.published, isEmpty);
  });

  test('a rejected re-publish is not counted', () async {
    entityPort.publishSucceeds = false;

    expect(await usecase([buildReport(entityId: 'mine-1')]), 0);
  });

  test('a transport failure degrades to zero', () async {
    source.throwOnFetch = StateError('host unreachable');

    expect(await usecase([buildReport(entityId: 'mine-1')]), 0);
  });

  test('nothing to send skips the host round trip entirely', () async {
    source.throwOnFetch = StateError('should not be called');

    expect(await usecase(const []), 0);
  });
}
