import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/catalog/jltv_pmcs_catalog.g.dart';
import 'package:ivy_pulse/data/catalog/stryker_pmcs_catalog.g.dart';
import 'package:ivy_pulse/data/services/tm_fault_classifier.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';

void main() {
  const classifier = TmFaultClassifier();

  group('serviceable', () {
    test('index 0 is never a fault, critical system or not', () {
      expect(classifier.classify(itemId: 'B-BRK-01', faultIndex: 0), isNull);
      expect(
        classifier.classify(itemId: 'JLTV-CRIT-B01', faultIndex: 0),
        isNull,
      );
      expect(classifier.classify(itemId: 'B-EXT-05', faultIndex: 0), isNull);
    });
  });

  group('critical systems', () {
    test('the TM "Not Mission Capable If" JLTV items are critical', () {
      expect(classifier.isCriticalSystem('JLTV-CRIT-B01'), isTrue);
      expect(classifier.isCriticalSystem('JLTV-B03'), isFalse);
    });

    test('the Stryker systems a vehicle is deadlined over are critical', () {
      for (final id in [
        'B-ENG-01',
        'B-ENG-02',
        'B-BRK-01',
        'D-DRV-01',
        'D-DRV-02',
        'B-FUL-03',
        'B-WPN-01',
      ]) {
        expect(classifier.isCriticalSystem(id), isTrue, reason: id);
      }
    });

    test('an ordinary item is not critical', () {
      expect(classifier.isCriticalSystem('B-BII-03'), isFalse);
      expect(classifier.isCriticalSystem('A-DOC-02'), isFalse);
    });

    test('the worst tier on a critical system deadlines the vehicle', () {
      expect(
        classifier.classify(itemId: 'B-BRK-01', faultIndex: 3),
        FaultSeverity.redX,
      );
      expect(
        classifier.classify(itemId: 'JLTV-CRIT-B01', faultIndex: 3),
        FaultSeverity.redX,
      );
    });

    test('a lesser fault on a critical system restricts but does not ground',
        () {
      expect(
        classifier.classify(itemId: 'B-BRK-01', faultIndex: 1),
        FaultSeverity.circleX,
      );
      expect(
        classifier.classify(itemId: 'B-BRK-01', faultIndex: 2),
        FaultSeverity.circleX,
      );
    });
  });

  group('ordinary systems', () {
    test('the worst tier restricts rather than grounds', () {
      expect(
        classifier.classify(itemId: 'B-EXT-01', faultIndex: 3),
        FaultSeverity.circleX,
      );
      expect(
        classifier.classify(itemId: 'B-EXT-01', faultIndex: 4),
        FaultSeverity.circleX,
      );
    });

    test('a minor tier is a deferrable DASH', () {
      expect(
        classifier.classify(itemId: 'B-EXT-01', faultIndex: 1),
        FaultSeverity.dash,
      );
      expect(
        classifier.classify(itemId: 'B-EXT-01', faultIndex: 2),
        FaultSeverity.dash,
      );
    });

    test('no ordinary item can ever produce a RED X', () {
      for (var index = 1; index <= 6; index++) {
        expect(
          classifier.classify(itemId: 'B-BII-01', faultIndex: index),
          isNot(FaultSeverity.redX),
        );
      }
    });
  });

  group('over the real catalogs', () {
    test('every check in both catalogs classifies without throwing', () {
      for (final catalog in [strykerPmcsCatalog, jltvPmcsCatalog]) {
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            for (var i = 0; i < item.faults.length; i++) {
              final severity =
                  classifier.classify(itemId: item.id, faultIndex: i);
              expect(severity == null, i == 0, reason: '${item.id} index $i');
            }
          }
        }
      }
    });

    test('severity never decreases as the operator picks a worse condition',
        () {
      for (final catalog in [strykerPmcsCatalog, jltvPmcsCatalog]) {
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            var previous = 0;
            for (var i = 1; i < item.faults.length; i++) {
              final rank =
                  classifier.classify(itemId: item.id, faultIndex: i)!.rank;
              expect(rank, greaterThanOrEqualTo(previous),
                  reason: '${item.id} index $i');
              previous = rank;
            }
          }
        }
      }
    });

    test('every JLTV critical item can reach RED X', () {
      var checked = 0;
      for (final phase in PmcsPhase.values) {
        for (final item in jltvPmcsCatalog.itemsFor(phase)) {
          if (!classifier.isCriticalSystem(item.id)) continue;
          checked++;
          expect(
            classifier.classify(
                itemId: item.id, faultIndex: item.faults.length - 1),
            FaultSeverity.redX,
            reason: item.id,
          );
        }
      }
      expect(checked, greaterThan(0));
    });
  });
}
