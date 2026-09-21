import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/data/services/lattice_report_source.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';

import '../support/fakes.dart';

class FakeEntityService implements sdk.EntityService {
  List<sdk.Entity> entities = const [];
  bool throwsOnGetEntities = false;

  @override
  Future<List<sdk.Entity>> getEntities() async {
    if (throwsOnGetEntities) throw Exception('lattice offline');
    return entities;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A PMCS entity as it comes back off the host, defaulting to one this
/// extension published itself.
sdk.Entity makePmcsEntity({
  String id = 'entity-1',
  String? integrationName = AppConstants.extensionId,
  String? dataType = AppConstants.entityDataType,
  String? rawDescription,
  Map<String, Object?>? bodyOverride,
  bool? isLive,
  List<PmcsFault> faults = const [],
}) {
  final description = rawDescription ??
      jsonEncode(bodyOverride ??
          const PmcsReportCodec()
              .reportBody(buildReport(entityId: id, faults: faults)));

  return sdk.Entity(
    id: id,
    name: 'A-11 — FMC',
    lat: 33.0,
    lon: -84.0,
    disposition: sdk.Disposition.friendly,
    description: description,
    provenance: sdk.EntityProvenance(
      integrationName: integrationName,
      dataType: dataType,
    ),
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

  group('fetchRemotePmcsReports', () {
    test('returns nothing when the host holds no entities', () async {
      expect(await source.fetchRemotePmcsReports(), isEmpty);
    });

    test('returns reports for entities our provenance marks as ours', () async {
      entities.entities = [
        makePmcsEntity(id: 'ours-1'),
        makePmcsEntity(id: 'ours-2'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['ours-1', 'ours-2']);
      expect(reports.first.fromCallsign, 'Lattice');
    });

    test('skips an entity another extension published', () async {
      entities.entities = [
        makePmcsEntity(id: 'ours'),
        makePmcsEntity(id: 'theirs', integrationName: 'recovery_ops'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['ours']);
    });

    test('skips an entity of ours carrying a different data type', () async {
      entities.entities = [
        makePmcsEntity(id: 'ours'),
        makePmcsEntity(id: 'other-type', dataType: 'RECOVERY_REQUEST'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['ours']);
    });

    test('skips an entity with no provenance at all', () async {
      entities.entities = [
        makePmcsEntity(id: 'anonymous', integrationName: null, dataType: null),
      ];

      expect(await source.fetchRemotePmcsReports(), isEmpty);
    });

    test('skips a withdrawn PMCS — a tombstone is not a fault list', () async {
      entities.entities = [
        makePmcsEntity(id: 'live'),
        makePmcsEntity(id: 'withdrawn', isLive: false),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['live']);
    });

    test('treats an entity that never states isLive as live', () async {
      entities.entities = [makePmcsEntity(id: 'unstated')];

      expect(await source.fetchRemotePmcsReports(), hasLength(1));
    });

    test('one entity with an unreadable description does not cost the rest',
        () async {
      entities.entities = [
        makePmcsEntity(id: 'garbage', rawDescription: 'not json'),
        makePmcsEntity(id: 'good'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['good']);
    });

    test('skips a description missing the fields a report needs', () async {
      entities.entities = [
        makePmcsEntity(id: 'no-bumper', bodyOverride: const {
          'entityId': 'no-bumper',
          'vehicleType': 'STRYKER',
          'latitude': 33.0,
          'longitude': -84.0,
        }),
        makePmcsEntity(id: 'good'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['good']);
    });

    test('skips an entity naming a platform this build does not know',
        () async {
      entities.entities = [
        makePmcsEntity(id: 'abrams', bodyOverride: const {
          'entityId': 'abrams',
          'bumperNumber': 'C-31',
          'vehicleType': 'M1A2',
          'latitude': 33.0,
          'longitude': -84.0,
        }),
        makePmcsEntity(id: 'good'),
      ];

      final reports = await source.fetchRemotePmcsReports();
      expect(reports.map((r) => r.entityId), ['good']);
    });

    test('skips an entity with no description', () async {
      entities.entities = [
        sdk.Entity(
          id: 'bare',
          name: 'A-11',
          lat: 33.0,
          lon: -84.0,
          disposition: sdk.Disposition.friendly,
          provenance: const sdk.EntityProvenance(
            integrationName: AppConstants.extensionId,
            dataType: AppConstants.entityDataType,
          ),
        ),
      ];

      expect(await source.fetchRemotePmcsReports(), isEmpty);
    });

    test('the fault list rides along in the description', () async {
      entities.entities = [
        makePmcsEntity(id: 'deadlined', faults: [
          buildFault(severity: FaultSeverity.redX, note: 'leak'),
        ]),
      ];

      final report = (await source.fetchRemotePmcsReports()).single;
      expect(report.faults, hasLength(1));
      expect(report.faults.single.severity, FaultSeverity.redX);
      expect(report.faults.single.note, 'leak');
      expect(report.isDeadlined, isTrue);
    });

    test('a synced report is neither outgoing nor already read', () async {
      entities.entities = [makePmcsEntity()];

      final report = (await source.fetchRemotePmcsReports()).single;
      expect(report.isOutgoing, isFalse);
      expect(report.isRead, isFalse);
    });

    test('returns nothing rather than throwing when the host fails', () async {
      entities.throwsOnGetEntities = true;

      await expectLater(source.fetchRemotePmcsReports(), completion(isEmpty));
    });
  });

  group('fetchKnownPmcsEntityIds', () {
    test('returns our ids only', () async {
      entities.entities = [
        makePmcsEntity(id: 'ours'),
        makePmcsEntity(id: 'theirs', integrationName: 'recovery_ops'),
        makePmcsEntity(id: 'other-type', dataType: 'RECOVERY_REQUEST'),
      ];

      expect(await source.fetchKnownPmcsEntityIds(), {'ours'});
    });

    test('a withdrawn id is still taken and must not be republished over',
        () async {
      entities.entities = [
        makePmcsEntity(id: 'live'),
        makePmcsEntity(id: 'withdrawn', isLive: false),
      ];

      expect(await source.fetchKnownPmcsEntityIds(), {'live', 'withdrawn'});
    });

    test('an id whose description will not decode is still taken', () async {
      entities.entities = [
        makePmcsEntity(id: 'garbage', rawDescription: 'not json'),
      ];

      expect(await source.fetchKnownPmcsEntityIds(), {'garbage'});
    });

    test('returns nothing rather than throwing when the host fails', () async {
      entities.throwsOnGetEntities = true;

      await expectLater(source.fetchKnownPmcsEntityIds(), completion(isEmpty));
    });
  });
}
