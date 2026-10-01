import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/services/mesh_report_collection.dart';
import '../support/fake_mesh_items.dart';

const type = sdk.MeshDataTypePath(
    namespace: 'test', domain: 'reports', dataType: 'report', version: 'v1');

void main() {
  late FakeMeshItems items;
  late MeshReportCollection collection;
  setUp(() {
    items = FakeMeshItems();
    collection = MeshReportCollection(items: items, type: type);
  });

  test('stable report ID resolves to server item ID across fresh instances',
      () async {
    await collection.save('report-1', {'value': 1});
    final restarted = MeshReportCollection(items: items, type: type);
    await restarted.save('report-1', {'value': 2});
    expect(items.created, hasLength(1));
    expect(items.updated, ['server-1']);
    expect(MeshReportCollection.body((await restarted.snapshot())['report-1']),
        {'value': 2});
    expect(items.lastTtl, isNull);
  });

  test('retry after lost create response reuses committed item', () async {
    items.loseCreateResponse = true;
    await expectLater(
        collection.save('report-1', {'value': 1}), throwsStateError);
    await MeshReportCollection(items: items, type: type)
        .save('report-1', {'value': 1});
    expect(items.created, hasLength(1));
    expect(items.records, hasLength(1));
  });

  test('same-device concurrent writes serialize without duplicate creates',
      () async {
    await Future.wait([
      collection.save('r', {'value': 1}),
      collection.save('r', {'value': 2}),
    ]);
    expect(items.records, hasLength(1));
    expect(MeshReportCollection.body((await collection.snapshot())['r']),
        {'value': 2});
  });

  test('read failures never create a replacement item', () async {
    items.failList = true;
    await expectLater(collection.save('r', {}), throwsStateError);
    expect(items.created, isEmpty);
    items.failList = false;
    await collection.save('r', {});
    expect(items.created, hasLength(1));
  });

  test('missing schema fails and can recover after provisioning', () async {
    items.schemaRegistered = false;
    await expectLater(collection.save('r', {}), throwsStateError);
    expect(items.created, isEmpty);
    items.schemaRegistered = true;
    await collection.save('r', {});
    expect(items.created, hasLength(1));
  });

  test('dropped create or update is not acknowledged as persisted', () async {
    items.dropWrites = true;
    await expectLater(collection.save('r', {'value': 1}), throwsStateError);
    items.dropWrites = false;
    await collection.save('r', {'value': 1});
    items.dropWrites = true;
    await expectLater(collection.save('r', {'value': 2}), throwsStateError);
  });

  test('withdrawal survives a stale writer and is never overwritten', () async {
    await collection.save('r', {'value': 1});
    final live = items.records.values.single;
    await collection.withdraw('r');
    await items.updateItem(live.path, {
      'reportId': 'r',
      'withdrawn': false,
      'updatedAt': '2099-01-01T00:00:00Z',
      'report': {'value': 99}
    });
    expect(MeshReportCollection.withdrawn((await collection.snapshot())['r']!),
        isTrue);
    await collection.save('r', {'value': 3});
    expect(items.records, hasLength(2));
    await collection.withdraw('r');
    expect(items.records, hasLength(2));
  });

  test('deleting before publish prevents a queued report from resurrecting',
      () async {
    await collection.withdraw('r');
    await collection.save('r', {'value': 1});
    expect(items.records, hasLength(1));
    expect(MeshReportCollection.withdrawn(items.records.values.single), isTrue);
  });

  test('lost withdrawal response is recovered without another tombstone',
      () async {
    items.loseCreateResponse = true;
    await expectLater(collection.withdraw('r'), throwsStateError);
    await collection.withdraw('r');
    expect(items.records, hasLength(1));
  });

  test('replication duplicates use newest record and stable tie breaking',
      () async {
    items.seed(type, {
      'reportId': 'r',
      'updatedAt': '2026-01-01T00:00:00Z',
      'report': {'value': 1}
    });
    items.seed(type, {
      'reportId': 'r',
      'updatedAt': '2026-01-02T00:00:00Z',
      'report': {'value': 2}
    });
    items.seed(type, {
      'reportId': 'r',
      'updatedAt': '2026-01-02T00:00:00Z',
      'report': {'value': 3}
    });
    expect((await collection.snapshot()).length, 1);
    expect(MeshReportCollection.body((await collection.snapshot())['r']),
        {'value': 3});
  });

  test('unrelated or malformed IDs are excluded', () async {
    items.seed(type, {'reportId': ''});
    items.seed(type, {'reportId': 5});
    items.seed(
        const sdk.MeshDataTypePath(
            namespace: 'other',
            domain: 'reports',
            dataType: 'report',
            version: 'v1'),
        {'reportId': 'other'});
    expect(await collection.snapshot(), isEmpty);
    await expectLater(collection.save('', {}), throwsArgumentError);
  });

  test('merge preserves navigation fields on report retry', () async {
    await collection.save('r', {'navigatorLatitude': 1, 'issue': 'old'});
    await collection.save('r', {'issue': 'new'}, merge: true);
    expect(MeshReportCollection.body((await collection.snapshot())['r']),
        {'navigatorLatitude': 1, 'issue': 'new'});
  });
}
