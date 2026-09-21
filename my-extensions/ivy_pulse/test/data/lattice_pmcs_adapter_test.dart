import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/data/services/lattice_pmcs_adapter.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';

import '../support/fakes.dart';

/// Stands in for the host's entity bridge. [silentlyDropsUpserts] reproduces
/// the failure the adapter's read-back exists for: the host acknowledges the
/// upsert and then never persists it.
class FakeEntityService implements sdk.EntityService {
  final Map<String, sdk.Entity> stored = {};
  final List<sdk.Entity> upserted = [];
  bool silentlyDropsUpserts = false;
  bool throwsOnUpsert = false;
  bool throwsOnGetEntity = false;

  @override
  Future<String> upsertEntity(sdk.Entity entity) async {
    if (throwsOnUpsert) throw Exception('host rejected the entity');
    upserted.add(entity);
    if (!silentlyDropsUpserts) stored[entity.id] = entity;
    return entity.id;
  }

  @override
  Future<sdk.Entity?> getEntity(String entityId) async {
    if (throwsOnGetEntity) throw Exception('lattice offline');
    return stored[entityId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeEntityService entities;
  late LatticePmcsAdapter adapter;

  setUp(() {
    entities = FakeEntityService();
    adapter = LatticePmcsAdapter(entities: entities);
  });

  group('publishPmcsReport', () {
    test('reports success once the entity reads back from the host', () async {
      final ok = await adapter.publishPmcsReport(buildReport());

      expect(ok, isTrue);
      expect(entities.upserted.single.id, 'session-1');
    });

    test(
        'reports failure when the host accepts the upsert but the entity never '
        'reads back — the operator must not be told the vehicle is on the COP '
        'when nobody can see it', () async {
      entities.silentlyDropsUpserts = true;

      final ok = await adapter.publishPmcsReport(buildReport());

      expect(ok, isFalse);
      expect(entities.upserted, hasLength(1),
          reason: 'the upsert itself was accepted; only the read-back failed');
    });

    test('reports failure without propagating when the host throws', () async {
      entities.throwsOnUpsert = true;

      await expectLater(
          adapter.publishPmcsReport(buildReport()), completion(isFalse));
    });

    test('reports failure when the verifying read throws', () async {
      entities.throwsOnGetEntity = true;

      expect(await adapter.publishPmcsReport(buildReport()), isFalse);
    });

    test('the published entity carries the report fault list', () async {
      await adapter.publishPmcsReport(
        buildReport(faults: [buildFault(severity: FaultSeverity.redX)]),
      );

      final body = jsonDecode(entities.upserted.single.description!)
          as Map<String, Object?>;
      expect((body['faults'] as List), hasLength(1));
      expect(entities.upserted.single.provenance?.integrationName,
          AppConstants.extensionId);
    });
  });

  group('publishEncodedReport', () {
    test('publishes an entity rebuilt from the queued payload', () async {
      final report = buildReport(entityId: 'queued-1', bumperNumber: 'B-22');
      final payload = const PmcsReportCodec().encodeReport(report);

      final ok = await adapter.publishEncodedReport(
        entityId: 'queued-1',
        payload: payload,
        position: const LatLng(33.0, -84.0),
      );

      expect(ok, isTrue);
      expect(entities.upserted.single.id, 'queued-1');
      expect(entities.upserted.single.name, contains('B-22'));
    });

    test('an unreadable payload still reaches the map at the given position',
        () async {
      final ok = await adapter.publishEncodedReport(
        entityId: 'queued-2',
        payload: 'not json',
        position: const LatLng(35.5, -80.5),
      );

      expect(ok, isTrue);
      final published = entities.upserted.single;
      expect(published.lat, 35.5);
      expect(published.lon, -80.5);
      expect(published.description, 'not json');
    });

    test('a payload the host drops is reported as a failure', () async {
      entities.silentlyDropsUpserts = true;

      final ok = await adapter.publishEncodedReport(
        entityId: 'queued-3',
        payload: 'not json',
        position: const LatLng(33.0, -84.0),
      );

      expect(ok, isFalse);
    });
  });

  group('deletePmcsEntity', () {
    test('tombstones an entity that is still on the host', () async {
      await adapter.publishPmcsReport(buildReport(entityId: 'live-1'));
      entities.upserted.clear();

      final ok = await adapter.deletePmcsEntity('live-1');

      expect(ok, isTrue);
      final tombstone = entities.upserted.single;
      expect(tombstone.id, 'live-1');
      expect(tombstone.isLive, isFalse);
      expect(tombstone.expiryTime, isNotNull);
    });

    test('an entity already gone from the host counts as deleted', () async {
      final ok = await adapter.deletePmcsEntity('never-published');

      expect(ok, isTrue);
      expect(entities.upserted, isEmpty);
    });

    test('reports failure without propagating when the host throws', () async {
      entities.throwsOnGetEntity = true;

      await expectLater(
          adapter.deletePmcsEntity('live-1'), completion(isFalse));
    });

    test('the tombstone keeps the rest of the entity intact', () async {
      await adapter.publishPmcsReport(buildReport(entityId: 'live-2'));
      final original = entities.upserted.single;
      entities.upserted.clear();

      await adapter.deletePmcsEntity('live-2');

      final tombstone = entities.upserted.single;
      expect(tombstone.name, original.name);
      expect(tombstone.description, original.description);
      expect(tombstone.provenance?.integrationName, AppConstants.extensionId);
    });
  });
}
