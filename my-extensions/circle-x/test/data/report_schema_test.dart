import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/entities/attested_identity.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import '../support/report_schema.dart';

void main() {
  const codec = PmcsReportCodec();
  Map<String, Object?> record() => {
        'reportId': 'session-1',
        'withdrawn': false,
        'updatedAt': '2026-10-01T00:00:00Z',
        'report': codec.reportBody(buildReport(
          signature: buildSignature(),
          faults: [buildFault(itemId: 'engine')],
          maintainerReview: MaintainerReview(
            sourceReportId: 'original',
            faults: const [
              FaultReview(
                  itemId: 'engine', phase: PmcsPhase.before, verified: true)
            ],
            signature: buildSignature(),
          ),
        )),
      };
  Map body(Map data) => data['report'] as Map;
  Map review(Map data) => body(data)['maintainerReview'] as Map;

  void expectInvalid(Map<String, Object?> data) => expect(
        reportSchema.validate(data, validateFormats: true).isValid,
        isFalse,
      );

  test(
      'serializer output for all vehicles, phases, and severities passes the schema',
      () async {
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    for (final vehicle in VehicleType.values) {
      final report = buildReport(
        entityId: vehicle.wireName,
        vehicleType: vehicle,
        signature: buildSignature(),
        phases: PmcsPhase.values,
        faults: [
          for (final phase in PmcsPhase.values)
            for (final severity in FaultSeverity.values)
              buildFault(
                  itemId: '${phase.name}-${severity.name}',
                  phase: phase,
                  severity: severity)
        ],
      );
      expect(await store.publishPmcsReport(report), isTrue);
      expect(await store.publishPmcsReport(report), isTrue);
    }
    expect(await store.fetchRemotePmcsReports(),
        hasLength(VehicleType.values.length));
    expect(items.lastTtl, isNull);
  });

  test(
      'unsigned reports, unverified reasons, and typed attestations remain valid',
      () async {
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    final signatures = <PmcsSignature?>[
      null,
      for (final reason in CacRejection.values)
        buildUnverifiedSignature(blockedBy: reason),
      PmcsSignature.unverified(
        blockedBy: CacRejection.noCamera,
        signedAt: DateTime.utc(2026),
        attestedBy: const AttestedIdentity(
            edipi: '1087987498', firstName: 'JOHN', lastName: 'SMITH'),
      ),
      buildSignature(
          identity: buildIdentity(firstName: '', lastName: '', rank: '')),
    ];
    for (final (index, signature) in signatures.indexed) {
      expect(
          await store.publishPmcsReport(
              buildReport(entityId: '$index', signature: signature)),
          isTrue);
    }
    expect(await store.fetchRemotePmcsReports(), hasLength(signatures.length));
  });

  test('CAC review and permanent withdrawal validate through the actual writer',
      () async {
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    final report = codec.reportFromBody(body(record()).cast<String, Object?>(),
        fromCallsign: 'test')!;
    expect(await store.publishPmcsReport(report), isTrue);
    expect((await store.fetchRemotePmcsReports()).single.maintainerReview,
        isNotNull);
    expect(await store.deletePmcsEntity(report.entityId), isTrue);
    expect(items.created, hasLength(2));
    expect(items.created.last.containsKey('report'), isFalse);
    expect(items.lastTtl, isNull);
  });

  for (final severity in ['RED-X', '', 'FUTURE', null, 1]) {
    test('schema rejects invalid fault severity $severity', () {
      final data = record();
      ((body(data)['faults'] as List).single as Map)['severity'] = severity;
      expectInvalid(data);
    });
  }

  for (final location in ['phases', 'fault', 'review']) {
    test('schema restricts $location phases to known values', () {
      final data = record();
      switch (location) {
        case 'phases':
          body(data)['phases'] = ['BEFORE', 'UNKNOWN'];
        case 'fault':
          ((body(data)['faults'] as List).single as Map)['phase'] = 'UNKNOWN';
        case 'review':
          ((review(data)['faults'] as List).single as Map)['phase'] = 'UNKNOWN';
      }
      expectInvalid(data);
    });
  }

  for (final uic in [
    '',
    ' ',
    'W12',
    'W12ABCD',
    'W12!BC',
    'wj8taa',
    'WJ8TAA\n'
  ]) {
    test('schema rejects noncanonical UIC "$uic"', () {
      final data = record();
      body(data)['uic'] = uic;
      expectInvalid(data);
    });
  }

  for (final location in ['operator', 'maintainer']) {
    Map signature(Map data) =>
        (location == 'operator' ? body(data) : review(data))['signature']
            as Map;

    for (final edipi in [
      '',
      '123',
      'abcdefghij',
      '0123456789',
      '12345678901',
      '1087987498\n',
      1087987498
    ]) {
      test('schema rejects $location identity number $edipi', () {
        final data = record();
        (signature(data)['identity'] as Map)['edipi'] = edipi;
        expectInvalid(data);
      });
    }
    for (final key in ['edipi', 'firstName', 'lastName', 'verifiedAt']) {
      test('schema requires $key in $location identity', () {
        final data = record();
        (signature(data)['identity'] as Map).remove(key);
        expectInvalid(data);
      });
    }
    test(
        'schema refuses empty $location identity and contradictory verification',
        () {
      final empty = record();
      signature(empty)['identity'] = {};
      expectInvalid(empty);
      final contradictory = record();
      signature(contradictory)['verified'] = false;
      expectInvalid(contradictory);
    });
    test('schema validates $location identity dates and optional field types',
        () {
      for (final field in {
        'verifiedAt': 'bad-date',
        'cardExpiresOn': 'bad-date',
        'rank': 1
      }.entries) {
        final data = record();
        (signature(data)['identity'] as Map)[field.key] = field.value;
        expectInvalid(data);
      }
    });
  }

  test('typed identity requires valid ID and both names', () {
    for (final identity in [
      <String, Object?>{},
      {'edipi': '123', 'firstName': 'TEST', 'lastName': 'USER'},
      {'edipi': '1087987498', 'firstName': ' ', 'lastName': 'USER'},
      {'edipi': '1087987498', 'firstName': 'TEST', 'lastName': 2},
    ]) {
      final data = record();
      body(data)['signature'] = {
        ...buildUnverifiedSignature().toMap(),
        'attestedBy': identity,
      };
      expectInvalid(data);
    }
  });

  test(
      'withdrawal branches, bounds, dates, and additional properties remain enforced',
      () {
    final invalid = <Map<String, Object?>>[
      record()..remove('report'),
      record()..['withdrawn'] = true,
      record()..['withdrawn'] = 'false',
      record()..['unexpected'] = true,
      record()..['updatedAt'] = 'bad-date',
    ];
    for (final field in {
      'latitude': 91,
      'longitude': -181,
      'timestamp': 'bad-date',
      'unexpected': true
    }.entries) {
      final data = record();
      body(data)[field.key] = field.value;
      invalid.add(data);
    }
    for (final data in invalid) {
      expectInvalid(data);
    }
  });

  test('duplicate phases, empty reviews and oversized descriptions are refused',
      () {
    final phases = record();
    body(phases)['phases'] = ['BEFORE', 'BEFORE'];
    expectInvalid(phases);
    final empty = record();
    review(empty)['faults'] = [];
    expectInvalid(empty);
    final oversized = record();
    ((review(oversized)['faults'] as List).single as Map)['description'] =
        'x' * 2001;
    expectInvalid(oversized);
  });
}
