import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

import '../support/fakes.dart';

void main() {
  const codec = PmcsReportCodec();

  test('a report survives the round trip', () {
    final original = buildReport(
      entityId: 'entity-42',
      bumperNumber: 'HQ-2',
      vehicleType: VehicleType.jltv,
      faults: [
        buildFault(itemId: 'JLTV-CRIT-B01', severity: FaultSeverity.redX),
        buildFault(
          itemId: 'JLTV-B03',
          severity: FaultSeverity.dash,
          note: 'hairline crack',
        ),
      ],
    );

    final decoded =
        codec.decodeReport(codec.encodeReport(original), fromCallsign: 'GHOST');

    expect(decoded, isNotNull);
    expect(decoded!.entityId, 'entity-42');
    expect(decoded.bumperNumber, 'HQ-2');
    expect(decoded.vehicleType, VehicleType.jltv);
    expect(decoded.operator, original.operator);
    expect(decoded.uic, original.uic);
    expect(decoded.latitude, original.latitude);
    expect(decoded.longitude, original.longitude);
    expect(decoded.timestamp, original.timestamp);
    expect(decoded.phases, [PmcsPhase.before]);
  });

  test('faults survive with their grading and notes intact', () {
    final original = buildReport(faults: [
      buildFault(itemId: 'B-BRK-01', severity: FaultSeverity.redX),
      buildFault(
        itemId: 'B-ENG-01',
        severity: FaultSeverity.dash,
        note: 'a quart low',
      ),
    ]);

    final decoded =
        codec.decodeReport(codec.encodeReport(original), fromCallsign: 'Mesh')!;

    expect(decoded.faults, hasLength(2));
    expect(decoded.tally.redX, 1);
    expect(decoded.tally.dash, 1);
    expect(decoded.isDeadlined, isTrue);
    expect(
      decoded.faults.firstWhere((f) => f.itemId == 'B-ENG-01').note,
      'a quart low',
    );
    expect(
      decoded.faults.firstWhere((f) => f.itemId == 'B-BRK-01').category,
      'ENGINE COMPARTMENT',
    );
  });

  test('a received report is inbound and unread', () {
    final decoded = codec.decodeReport(
      codec.encodeReport(buildReport()),
      fromCallsign: 'GHOST',
    )!;

    expect(decoded.isOutgoing, isFalse);
    expect(decoded.isRead, isFalse);
    expect(decoded.fromCallsign, 'GHOST');
  });

  test('the payload is tagged so peers can tell it apart', () {
    final body =
        jsonDecode(codec.encodeReport(buildReport())) as Map<String, dynamic>;

    expect(body['type'], AppConstants.meshReportType);
  });

  test('a deletion round-trips to its entity id', () {
    expect(codec.decodeDeletion(codec.encodeDeletion('entity-7')), 'entity-7');
  });

  test('a report is not mistaken for a deletion, or the reverse', () {
    expect(codec.decodeDeletion(codec.encodeReport(buildReport())), isNull);
    expect(
      codec.decodeReport(codec.encodeDeletion('entity-7'),
          fromCallsign: 'Mesh'),
      isNull,
    );
  });

  test('another extension\'s traffic is ignored', () {
    const foreign = '{"type":"recovery_ops.request","entityId":"x"}';

    expect(codec.decodeReport(foreign, fromCallsign: 'Mesh'), isNull);
    expect(codec.decodeDeletion(foreign), isNull);
  });

  test('malformed traffic never throws', () {
    for (final payload in ['', 'not json', '{', '[]', '{"type":null}']) {
      expect(codec.decodeReport(payload, fromCallsign: 'Mesh'), isNull,
          reason: payload);
      expect(codec.decodeDeletion(payload), isNull, reason: payload);
    }
  });

  test('a report missing required fields is rejected rather than half-built',
      () {
    final body =
        jsonDecode(codec.encodeReport(buildReport())) as Map<String, dynamic>;
    body.remove('bumperNumber');

    expect(codec.decodeReport(jsonEncode(body), fromCallsign: 'Mesh'), isNull);
  });

  test('a clean PMCS encodes with no faults and decodes the same way', () {
    final decoded = codec.decodeReport(
      codec.encodeReport(buildReport()),
      fromCallsign: 'Mesh',
    )!;

    expect(decoded.faults, isEmpty);
    expect(decoded.isDeadlined, isFalse);
    expect(decoded.statusLabel, 'FMC');
  });

  test('the entity body and the mesh body are the same shape', () {
    final report = buildReport(faults: [buildFault()]);
    final meshBody =
        jsonDecode(codec.encodeReport(report)) as Map<String, dynamic>;
    final entityBody = codec.reportBody(report);

    for (final key in entityBody.keys) {
      expect(meshBody.containsKey(key), isTrue, reason: key);
    }

    final fromEntity =
        codec.reportFromBody(entityBody, fromCallsign: 'Lattice');
    expect(fromEntity?.entityId, report.entityId);
    expect(fromEntity?.faults, hasLength(1));
  });

  group('the signature on the wire', () {
    test('a verified signature survives the round trip', () {
      const codec = PmcsReportCodec();
      final original = buildReport(signature: buildSignature());

      final decoded = codec.decodeReport(
        codec.encodeReport(original),
        fromCallsign: 'Mesh',
      )!;

      expect(decoded.isSignatureVerified, isTrue);
      expect(decoded.signature!.identity!.edipi, '1087987498');
      expect(decoded.signature!.identity!.displayName, 'SGT SMITH, JOHN A');
    });

    test('an unverified signature arrives unverified, with its reason', () {
      const codec = PmcsReportCodec();
      final original = buildReport(
        signature: buildUnverifiedSignature(blockedBy: CacRejection.noCamera),
      );

      final decoded = codec.decodeReport(
        codec.encodeReport(original),
        fromCallsign: 'Mesh',
      )!;

      expect(decoded.isSignatureVerified, isFalse);
      expect(decoded.signature!.blockedBy, CacRejection.noCamera);
    });

    test('a payload from a build with no CAC verification still decodes', () {
      // Backward compatibility matters more than the signature: a report from
      // an older crew is still a deadlined vehicle somebody has to recover.
      const codec = PmcsReportCodec();
      final body = codec.reportBody(buildReport())..remove('signature');

      final decoded =
          codec.reportFromBody(body, fromCallsign: 'Mesh')!;

      expect(decoded.bumperNumber, 'A-11');
      expect(decoded.signature, isNull);
      expect(decoded.isSignatureVerified, isFalse);
    });

    test('a garbled signature block costs the signature, never the report',
        () {
      const codec = PmcsReportCodec();
      final body = codec.reportBody(buildReport())
        ..['signature'] = 'not an object';

      final decoded = codec.reportFromBody(body, fromCallsign: 'Mesh')!;

      expect(decoded.bumperNumber, 'A-11');
      expect(decoded.isSignatureVerified, isFalse);
    });

    test('no date of birth is ever put on the wire', () {
      const codec = PmcsReportCodec();

      final payload = codec.encodeReport(
        buildReport(signature: buildSignature()),
      );

      expect(payload, isNot(contains('1980')));
      expect(payload, isNot(contains('dateOfBirth')));
    });
  });
}
