import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';

import '../../support/fakes.dart';

void main() {
  group('FaultTally', () {
    test('counts each severity', () {
      final tally = FaultTally.from([
        buildFault(itemId: 'a', severity: FaultSeverity.redX),
        buildFault(itemId: 'b', severity: FaultSeverity.redX),
        buildFault(itemId: 'c', severity: FaultSeverity.circleX),
        buildFault(itemId: 'd', severity: FaultSeverity.dash),
      ]);

      expect(tally.redX, 2);
      expect(tally.circleX, 1);
      expect(tally.dash, 1);
      expect(tally.total, 4);
    });

    test('is empty for no faults', () {
      const tally = FaultTally();
      expect(tally.isEmpty, isTrue);
      expect(tally.worst, isNull);
      expect(tally.isDeadlined, isFalse);
    });

    test('any RED X deadlines the vehicle', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.dash),
        buildFault(itemId: 'b', severity: FaultSeverity.redX),
      ]);

      expect(tally.isDeadlined, isTrue);
      expect(tally.worst, FaultSeverity.redX);
    });

    test('CIRCLE X alone does not deadline', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.circleX),
      ]);

      expect(tally.isDeadlined, isFalse);
      expect(tally.worst, FaultSeverity.circleX);
    });

    test('countOf reads back each bucket', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.circleX),
      ]);

      expect(tally.countOf(FaultSeverity.circleX), 1);
      expect(tally.countOf(FaultSeverity.redX), 0);
    });
  });

  group('FaultSeverity', () {
    test('only RED X deadlines', () {
      expect(FaultSeverity.redX.deadlinesVehicle, isTrue);
      expect(FaultSeverity.circleX.deadlinesVehicle, isFalse);
      expect(FaultSeverity.dash.deadlinesVehicle, isFalse);
    });

    test('DASH may be deferred, the others may not', () {
      expect(FaultSeverity.dash.requiresCorrection, isFalse);
      expect(FaultSeverity.circleX.requiresCorrection, isTrue);
      expect(FaultSeverity.redX.requiresCorrection, isTrue);
    });

    test('round-trips through its wire name', () {
      for (final severity in FaultSeverity.values) {
        expect(FaultSeverity.fromWireName(severity.wireName), severity);
      }
      expect(FaultSeverity.tryFromWireName('NOPE'), isNull);
      expect(FaultSeverity.tryFromWireName(null), isNull);
    });

    test('ranks most severe highest', () {
      expect(FaultSeverity.redX.rank, greaterThan(FaultSeverity.circleX.rank));
      expect(FaultSeverity.circleX.rank, greaterThan(FaultSeverity.dash.rank));
    });
  });

  group('mission-capable status', () {
    test('a clean PMCS is fully mission capable', () {
      const tally = FaultTally();
      expect(tally.missionCapabilityLabel, 'FMC');
      expect(tally.missionCapabilityDetail, contains('no deficiencies'));
    });

    test('DASH alone stays mission capable but is noted', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.dash),
      ]);
      expect(tally.missionCapabilityLabel, 'FMC (DASH)');
    });

    test('CIRCLE X limits the vehicle to mission-essential runs', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.circleX),
        buildFault(itemId: 'b', severity: FaultSeverity.dash),
      ]);
      expect(tally.missionCapabilityLabel, 'LIMITED');
      expect(tally.missionCapabilityDetail, contains('commander approval'));
    });

    test('a RED X deadlines the vehicle regardless of what else is open', () {
      final tally = FaultTally.from([
        buildFault(severity: FaultSeverity.dash),
        buildFault(itemId: 'b', severity: FaultSeverity.circleX),
        buildFault(itemId: 'c', severity: FaultSeverity.redX),
      ]);
      expect(tally.missionCapabilityLabel, 'NMC');
      expect(tally.missionCapabilityDetail, contains('deadlined'));
    });

    test('a report grades itself off the same tally', () {
      final report = buildReport(faults: [
        buildFault(severity: FaultSeverity.redX),
      ]);
      expect(report.statusLabel, report.tally.missionCapabilityLabel);
      expect(report.statusLabel, 'NMC');
    });
  });
}
