import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/services/latticeReportSource.dart';

class FakeEntityService implements sdk.EntityService {
  List<sdk.Entity> entities = const [];
  Map<String, sdk.Entity?> entityById = {};
  bool shouldThrowOnGetAll = false;
  bool shouldThrowOnGetEntity = false;

  @override
  Future<List<sdk.Entity>> getEntities() async {
    if (shouldThrowOnGetAll) throw Exception('lattice offline');
    return entities;
  }

  @override
  Future<sdk.Entity?> getEntity(String entityId) async {
    if (shouldThrowOnGetEntity) throw Exception('lattice offline');
    return entityById[entityId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

sdk.Entity makeRecoveryEntity({
  String id = 'entity-1',
  String integrationName = 'recovery_ops',
  String dataType = 'RECOVERY_REQUEST',
  Map<String, dynamic>? overrideDescription,
  String? rawDescription,
  DateTime? createdTime,
  bool? isLive,
}) {
  final description = rawDescription ??
      jsonEncode(overrideDescription ??
          {
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
          });

  return sdk.Entity(
    id: id,
    name: 'HQ-42 - Wrecker Recovery',
    lat: 33.0,
    lon: -84.0,
    disposition: sdk.Disposition.friendly,
    description: description,
    provenance: sdk.EntityProvenance(
      integrationName: integrationName,
      dataType: dataType,
    ),
    createdTime: createdTime,
    isLive: isLive,
  );
}

void main() {
  late FakeEntityService entities;
  late LatticeReportSource source;

  setUp(() {
    entities = FakeEntityService();
    source = LatticeReportSource(entities: entities);
  });

  group('fetchRemoteRecoveryReports', () {
    test('returns empty list when no entities exist', () async {
      entities.entities = const [];
      final result = await source.fetchRemoteRecoveryReports();
      expect(result, isEmpty);
    });

    test('parses valid recovery request entities', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'entity-1'),
        makeRecoveryEntity(id: 'entity-2'),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 2);
      expect(result.map((r) => r.entityId), containsAll(['entity-1', 'entity-2']));
      expect(result.first.fromCallsign, 'Mesh');
    });

    test('skips entities with foreign integrationName', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'keep'),
        makeRecoveryEntity(id: 'skip', integrationName: 'other_extension'),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      expect(result.first.entityId, 'keep');
    });

    test('skips entities with non-RECOVERY_REQUEST dataType', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'keep'),
        makeRecoveryEntity(id: 'skip', dataType: 'SOMETHING_ELSE'),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      expect(result.first.entityId, 'keep');
    });

    test('skips entities with missing required description fields', () async {
      entities.entities = [
        makeRecoveryEntity(
          id: 'missing-bumper',
          overrideDescription: {
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
          },
        ),
        makeRecoveryEntity(id: 'complete'),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      expect(result.first.entityId, 'complete');
    });

    test('skips entities with malformed description JSON', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'bad', rawDescription: 'not json'),
        makeRecoveryEntity(id: 'good'),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      expect(result.first.entityId, 'good');
    });

    test('parses optional navigator and geometry fields when present', () async {
      entities.entities = [
        makeRecoveryEntity(
          id: 'entity-1',
          overrideDescription: {
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
            'navigatorLatitude': 34.5,
            'navigatorLongitude': -85.5,
            'routeGeometry': [
              [33.0, -84.0],
              [34.0, -85.0],
            ],
          },
        ),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      final report = result.first;
      expect(report.navigatorLatitude, 34.5);
      expect(report.navigatorLongitude, -85.5);
      expect(report.routeGeometry, isNotNull);
      expect(report.routeGeometry!.length, 2);
    });

    test('uses entity.createdTime as the report timestamp', () async {
      final createdTime = DateTime.utc(2026, 4, 10, 9);
      entities.entities = [
        makeRecoveryEntity(id: 'entity-1', createdTime: createdTime),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.first.timestamp, createdTime);
    });

    test('returns empty list when getEntities throws', () async {
      entities.shouldThrowOnGetAll = true;
      final result = await source.fetchRemoteRecoveryReports();
      expect(result, isEmpty);
    });

    test('marks synced reports as not outgoing and unread', () async {
      entities.entities = [makeRecoveryEntity(id: 'entity-1')];
      final result = await source.fetchRemoteRecoveryReports();
      expect(result.first.isOutgoing, isFalse);
      expect(result.first.isRead, isFalse);
    });

    test('skips tombstoned entities (isLive == false)', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'live'),
        makeRecoveryEntity(id: 'dead', isLive: false),
      ];

      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
      expect(result.first.entityId, 'live');
    });

    test('includes entities with isLive == null as live by default', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'unspecified'),
      ];
      final result = await source.fetchRemoteRecoveryReports();
      expect(result.length, 1);
    });
  });

  group('fetchKnownRecoveryEntityIds', () {
    test('returns empty set when no entities exist', () async {
      entities.entities = const [];
      final result = await source.fetchKnownRecoveryEntityIds();
      expect(result, isEmpty);
    });

    test('includes both live and tombstoned owned entities', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'live'),
        makeRecoveryEntity(id: 'tombstoned', isLive: false),
      ];
      final result = await source.fetchKnownRecoveryEntityIds();
      expect(result, containsAll(['live', 'tombstoned']));
      expect(result, hasLength(2));
    });

    test('skips entities owned by a different integration', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'ours'),
        makeRecoveryEntity(id: 'foreign', integrationName: 'other_extension'),
      ];
      final result = await source.fetchKnownRecoveryEntityIds();
      expect(result, {'ours'});
    });

    test('skips entities with non-RECOVERY_REQUEST dataType', () async {
      entities.entities = [
        makeRecoveryEntity(id: 'ours'),
        makeRecoveryEntity(id: 'other-type', dataType: 'SOMETHING_ELSE'),
      ];
      final result = await source.fetchKnownRecoveryEntityIds();
      expect(result, {'ours'});
    });

    test('returns empty set when getEntities throws', () async {
      entities.shouldThrowOnGetAll = true;
      final result = await source.fetchKnownRecoveryEntityIds();
      expect(result, isEmpty);
    });
  });

  group('fetchNavigatorState', () {
    test('returns null when entity is not found', () async {
      entities.entityById = {'entity-1': null};
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNull);
    });

    test('returns null when entity has no description', () async {
      entities.entityById = {
        'entity-1': sdk.Entity(
          id: 'entity-1',
          name: 'x',
          lat: 33.0,
          lon: -84.0,
          disposition: sdk.Disposition.friendly,
        ),
      };
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNull);
    });

    test('returns null when navigator fields are missing', () async {
      entities.entityById = {
        'entity-1': makeRecoveryEntity(
          id: 'entity-1',
          overrideDescription: {
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
          },
        ),
      };
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNull);
    });

    test('returns parsed navigator state when present', () async {
      entities.entityById = {
        'entity-1': makeRecoveryEntity(
          id: 'entity-1',
          overrideDescription: {
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
            'navigatorLatitude': 34.5,
            'navigatorLongitude': -85.5,
          },
        ),
      };
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNotNull);
      expect(result!.entityId, 'entity-1');
      expect(result.navigatorLatitude, 34.5);
      expect(result.navigatorLongitude, -85.5);
      expect(result.stopped, isFalse);
    });

    test('parses routeGeometry when present', () async {
      entities.entityById = {
        'entity-1': makeRecoveryEntity(
          id: 'entity-1',
          overrideDescription: {
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'vehicleLatitude': 33.0,
            'vehicleLongitude': -84.0,
            'navigatorLatitude': 34.5,
            'navigatorLongitude': -85.5,
            'routeGeometry': [
              [33.0, -84.0],
              [34.0, -85.0],
              [34.5, -85.5],
            ],
          },
        ),
      };
      final result = await source.fetchNavigatorState('entity-1');
      expect(result!.routeGeometry, isNotNull);
      expect(result.routeGeometry!.length, 3);
      expect(result.routeGeometry!.first.latitude, 33.0);
      expect(result.routeGeometry!.last.longitude, -85.5);
    });

    test('returns null on malformed description JSON', () async {
      entities.entityById = {
        'entity-1': makeRecoveryEntity(
          id: 'entity-1',
          rawDescription: 'not json',
        ),
      };
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNull);
    });

    test('returns null when getEntity throws', () async {
      entities.shouldThrowOnGetEntity = true;
      final result = await source.fetchNavigatorState('entity-1');
      expect(result, isNull);
    });
  });
}
