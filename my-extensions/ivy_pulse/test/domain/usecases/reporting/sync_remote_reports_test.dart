import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemoteReportSource source;
  late FakeReportsRepository repository;
  late SyncRemoteReports usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    repository = FakeReportsRepository();
    usecase = SyncRemoteReports(source, repository);
  });

  test('stores reports this device has not seen', () async {
    source.remote = [
      buildReport(entityId: 'remote-1', isOutgoing: false),
      buildReport(entityId: 'remote-2', isOutgoing: false),
    ];

    final fresh = await usecase(const []);

    expect(fresh, hasLength(2));
    expect(repository.reports, hasLength(2));
  });

  test('skips reports already held locally', () async {
    source.remote = [buildReport(entityId: 'remote-1', isOutgoing: false)];

    final fresh = await usecase([buildReport(entityId: 'remote-1')]);

    expect(fresh, isEmpty);
    expect(repository.reports, isEmpty);
  });

  test('does not re-store a duplicate inside the same batch', () async {
    source.remote = [
      buildReport(entityId: 'dup', isOutgoing: false),
      buildReport(entityId: 'dup', isOutgoing: false),
    ];

    final fresh = await usecase(const []);

    expect(fresh, hasLength(1));
  });

  test('ignores reports with no entity id', () async {
    source.remote = [buildReport(entityId: '', isOutgoing: false)];

    expect(await usecase(const []), isEmpty);
  });

  test('returns the stored copies, which carry row ids', () async {
    source.remote = [buildReport(entityId: 'remote-1', isOutgoing: false)];

    final fresh = await usecase(const []);

    expect(fresh.single.id, isNotNull);
  });

  test('an empty remote set is not an error', () async {
    expect(await usecase(const []), isEmpty);
  });

  test('a transport failure degrades to no new reports', () async {
    source.throwOnFetch = StateError('host unreachable');

    expect(await usecase(const []), isEmpty);
  });
}
