import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/data/services/lattice_entity_adapter.dart';

import '../support/sdk_delivery_fakes.dart';

void main() {
  late RecordingEntityService entities;
  late LatticeEntityAdapter adapter;
  const vehicle = LatLng(33.25, -84.5);
  const navigator = LatLng(34, -85);

  setUp(() {
    entities = RecordingEntityService();
    adapter = LatticeEntityAdapter(entities: entities);
  });

  Future<bool> publish() => adapter.publishRecoveryEntity(
        entityId: 'recovery-1',
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        typeName: 'Wrecker',
        position: vehicle,
      );

  Future<bool> publishNavigator() => adapter.publishNavigatorEntity(
        entityId: 'recovery-1',
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        typeName: 'Wrecker',
        vehiclePosition: vehicle,
        navigatorPosition: navigator,
        routeGeometry: [navigator, vehicle],
      );

  test('publishes a live recovery with the data needed by remote readers',
      () async {
    expect(await publish(), isTrue);
    final entity = entities.upserts.single;
    expect(entity.id, 'recovery-1');
    expect(entity.name, 'HQ-42 - Wrecker Recovery');
    expect(entity.lat, vehicle.latitude);
    expect(entity.lon, vehicle.longitude);
    expect(entity.isLive, isTrue);
    expect(entity.provenance!.integrationName, 'recovery_ops');
    expect(entity.provenance!.dataType, 'RECOVERY_REQUEST');
    expect(entity.expiryTime!.difference(entity.createdTime!),
        const Duration(days: 1));
    expect(jsonDecode(entity.description!), {
      'bumperNumber': 'HQ-42',
      'issue': 'flat tire',
      'recoveryType': 'Wrecker',
      'vehicleLatitude': 33.25,
      'vehicleLongitude': -84.5,
      'navigatorLatitude': null,
      'navigatorLongitude': null,
      'routeGeometry': null,
    });
  });

  test('does not report delivery when the host failed to persist the entity',
      () async {
    entities.persistWrites = false;
    expect(await publish(), isFalse);
    expect(entities.upserts, hasLength(1));
  });

  test('failed verification is a failed delivery', () async {
    entities.failRead = true;
    expect(await publish(), isFalse);
  });

  test('an unavailable host returns failure without losing control to an error',
      () async {
    entities.failWrite = true;
    expect(await publish(), isFalse);
    expect(entities.upserts, isEmpty);
  });

  test('navigator updates preserve vehicle position and ordered route points',
      () async {
    expect(await publishNavigator(), isTrue);
    final entity = entities.upserts.single;
    final body = jsonDecode(entity.description!) as Map<String, dynamic>;
    expect(entity.lat, vehicle.latitude);
    expect(entity.lon, vehicle.longitude);
    expect(body['navigatorLatitude'], navigator.latitude);
    expect(body['navigatorLongitude'], navigator.longitude);
    expect(body['routeGeometry'], [
      [34.0, -85.0],
      [33.25, -84.5]
    ]);
    expect(entity.routeDetails!['destinationName'], 'HQ-42 - Wrecker');
  });

  test('navigator publishing reports host write failure', () async {
    entities.failWrite = true;
    expect(await publishNavigator(), isFalse);
  });

  test('deletion tombstones the existing recovery and retains its payload',
      () async {
    await publish();
    final original = entities.upserts.single;
    expect(await adapter.deleteRecoveryEntity(original.id), isTrue);

    final tombstone = entities.upserts.last;
    expect(tombstone.id, original.id);
    expect(tombstone.description, original.description);
    expect(tombstone.isLive, isFalse);
    expect(tombstone.expiryTime!.isAfter(DateTime.now().toUtc()), isFalse);
  });

  test('deleting an absent recovery succeeds without creating an entity',
      () async {
    expect(await adapter.deleteRecoveryEntity('absent'), isTrue);
    expect(entities.upserts, isEmpty);
  });

  test('deletion fails when the host cannot read or write the tombstone',
      () async {
    await publish();
    entities.failWrite = true;
    expect(await adapter.deleteRecoveryEntity('recovery-1'), isFalse);
    expect(entities.entities['recovery-1']!.isLive, isTrue);
    entities.failRead = true;
    expect(await adapter.deleteRecoveryEntity('recovery-1'), isFalse);
  });
}
