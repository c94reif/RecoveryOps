import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/mappers/pmcs_entity_mapper.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

import '../support/fakes.dart';

void main() {
  late PmcsEntityMapper mapper;

  setUp(() {
    mapper = const PmcsEntityMapper();
  });

  group('buildEntity', () {
    test('stamps our provenance so the entity is recognised as ours', () {
      final entity = mapper.buildEntity(buildReport(entityId: 'report-1'));

      expect(entity.id, 'report-1');
      expect(entity.provenance?.integrationName, AppConstants.extensionId);
      expect(entity.provenance?.dataType, AppConstants.entityDataType);
      expect(entity.provenance?.sourceId, 'report-1');
      expect(mapper.isOwnedPmcsEntity(entity), isTrue);
    });

    test('plots the entity where the vehicle was inspected', () {
      final entity = mapper.buildEntity(buildReport());

      expect(entity.lat, 33.0);
      expect(entity.lon, -84.0);
      expect(entity.environment, 'land');
    });

    test('carries a description a receiving device can decode', () {
      final report = buildReport(
        entityId: 'report-2',
        faults: [buildFault(severity: FaultSeverity.circleX, note: 'seeping')],
      );

      final decoded = mapper.parseRemoteEntity(mapper.buildEntity(report));

      expect(decoded, isNotNull);
      expect(decoded!.entityId, 'report-2');
      expect(decoded.bumperNumber, report.bumperNumber);
      expect(decoded.vehicleType, VehicleType.stryker);
      expect(decoded.phases, [PmcsPhase.before]);
      expect(decoded.faults.single.severity, FaultSeverity.circleX);
      expect(decoded.faults.single.note, 'seeping');
    });

    test('expires after one dispatch day so a stale PMCS leaves the map', () {
      final entity = mapper.buildEntity(buildReport());

      expect(entity.isLive, isTrue);
      expect(entity.createdTime, isNotNull);
      expect(
        entity.expiryTime!.difference(entity.createdTime!),
        AppConstants.entityTtl,
      );
      expect(entity.expiryTime!.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('a RED X deadlines the vehicle: hostile tint, NMC name', () {
      final entity = mapper.buildEntity(
        buildReport(faults: [buildFault(severity: FaultSeverity.redX)]),
      );

      expect(entity.disposition, sdk.Disposition.hostile);
      expect(entity.name, 'A-11 — NMC');
      expect(entity.status?.role, 'NMC');
      expect(entity.ontology?.specificType, 'NMC');
    });

    test('a clean PMCS stays friendly and reads FMC', () {
      final entity = mapper.buildEntity(buildReport());

      expect(entity.disposition, sdk.Disposition.friendly);
      expect(entity.name, 'A-11 — FMC');
      expect(entity.status?.role, 'FMC');
    });

    test('the platform is on the ontology for the COP to sort by', () {
      final entity =
          mapper.buildEntity(buildReport(vehicleType: VehicleType.jltv));

      expect(entity.ontology?.platformType, 'JLTV');
      expect(entity.alternateIds.single.id, 'session-1');
    });
  });

  group('buildEntityFromPayload', () {
    test('a readable queued payload rebuilds the full entity', () {
      final report = buildReport(entityId: 'queued-1', bumperNumber: 'B-22');
      final payload = const PmcsReportCodec().encodeReport(report);

      final entity = mapper.buildEntityFromPayload(
        entityId: 'queued-1',
        payload: payload,
        position: const LatLng(0, 0),
      );

      expect(entity.id, 'queued-1');
      expect(entity.name, 'B-22 — FMC');
      expect(entity.lat, 33.0,
          reason: 'the payload position wins over the '
              'fallback the caller supplied');
    });

    test('an unreadable payload still gets a pin the maintainer can chase', () {
      final entity = mapper.buildEntityFromPayload(
        entityId: 'queued-2',
        payload: 'not json',
        position: const LatLng(35.5, -80.5),
      );

      expect(entity.id, 'queued-2');
      expect(entity.name, 'PMCS queued-2');
      expect(entity.lat, 35.5);
      expect(entity.lon, -80.5);
      expect(entity.description, 'not json');
      expect(mapper.isOwnedPmcsEntity(entity), isTrue);
    });
  });

  group('isOwnedPmcsEntity', () {
    sdk.Entity entityWith({String? integrationName, String? dataType}) {
      return sdk.Entity(
        id: 'e1',
        name: 'x',
        lat: 33.0,
        lon: -84.0,
        disposition: sdk.Disposition.friendly,
        provenance: sdk.EntityProvenance(
          integrationName: integrationName,
          dataType: dataType,
        ),
      );
    }

    test('rejects another extension entity', () {
      expect(
        mapper.isOwnedPmcsEntity(entityWith(
          integrationName: 'recovery_ops',
          dataType: AppConstants.entityDataType,
        )),
        isFalse,
      );
    });

    test('rejects one of ours carrying a different data type', () {
      expect(
        mapper.isOwnedPmcsEntity(entityWith(
          integrationName: AppConstants.extensionId,
          dataType: 'RECOVERY_REQUEST',
        )),
        isFalse,
      );
    });

    test('rejects an entity with no provenance', () {
      expect(
        mapper.isOwnedPmcsEntity(sdk.Entity(
          id: 'e1',
          name: 'x',
          lat: 33.0,
          lon: -84.0,
          disposition: sdk.Disposition.friendly,
        )),
        isFalse,
      );
    });
  });

  group('parseRemoteEntity', () {
    sdk.Entity entityDescribed(String? description) => sdk.Entity(
          id: 'e1',
          name: 'x',
          lat: 33.0,
          lon: -84.0,
          disposition: sdk.Disposition.friendly,
          description: description,
        );

    test('round-trips a report the mapper built', () {
      final report = buildReport(
        entityId: 'round-trip',
        vehicleType: VehicleType.jltv,
        faults: [
          buildFault(severity: FaultSeverity.redX),
          buildFault(itemId: 'B-BRK-01', severity: FaultSeverity.dash),
        ],
      );

      final parsed = mapper.parseRemoteEntity(mapper.buildEntity(report));

      expect(parsed!.entityId, report.entityId);
      expect(parsed.vehicleType, VehicleType.jltv);
      expect(parsed.operator, report.operator);
      expect(parsed.uic, report.uic);
      expect(parsed.latitude, report.latitude);
      expect(parsed.longitude, report.longitude);
      expect(parsed.timestamp.toUtc(), report.timestamp.toUtc());
      expect(parsed.faults.map((f) => f.severity),
          [FaultSeverity.redX, FaultSeverity.dash]);
      expect(parsed.statusLabel, report.statusLabel);
      expect(parsed.fromCallsign, 'Lattice',
          reason: 'a report read off the host came from Lattice, not us');
      expect(parsed.isOutgoing, isFalse);
    });

    test('returns null for a description that is not JSON', () {
      expect(mapper.parseRemoteEntity(entityDescribed('not json')), isNull);
    });

    test('returns null for a JSON description that is not an object', () {
      expect(mapper.parseRemoteEntity(entityDescribed('[1,2,3]')), isNull);
    });

    test('returns null when there is no description at all', () {
      expect(mapper.parseRemoteEntity(entityDescribed(null)), isNull);
    });

    test('returns null when the body names an unknown platform', () {
      final body = jsonEncode({
        'type': AppConstants.meshReportType,
        'entityId': 'e1',
        'bumperNumber': 'C-31',
        'vehicleType': 'M1A2',
        'latitude': 33.0,
        'longitude': -84.0,
      });

      expect(mapper.parseRemoteEntity(entityDescribed(body)), isNull);
    });
  });

  group('the signature on the Lattice entity', () {
    test('survives buildEntity and parseRemoteEntity', () {
      // The entity description is the only copy a receiving crew gets, so a
      // signature that does not make this trip is a signature the maintainer
      // never sees.
      const mapper = PmcsEntityMapper();
      final report = buildReport(signature: buildSignature());

      final parsed = mapper.parseRemoteEntity(mapper.buildEntity(report))!;

      expect(parsed.isSignatureVerified, isTrue);
      expect(parsed.signature!.identity!.edipi, '1087987498');
    });

    test('an unverified report stays unverified on the COP', () {
      const mapper = PmcsEntityMapper();
      final report = buildReport(signature: buildUnverifiedSignature());

      final parsed = mapper.parseRemoteEntity(mapper.buildEntity(report))!;

      expect(parsed.isSignatureVerified, isFalse);
      expect(parsed.signature!.blockedBy, isNotNull);
    });
  });
}
