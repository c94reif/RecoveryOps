import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_readiness/report_state.dart';

void main() {
  group('EquipmentStatus', () {
    test('defaults to zero counts', () {
      final status = EquipmentStatus(equipmentId: 'm1151');
      expect(status.fmc, 0);
      expect(status.pmc, 0);
      expect(status.nmc, 0);
    });

    test('total sums all counts', () {
      final status = EquipmentStatus(equipmentId: 'm1151', fmc: 5, pmc: 2, nmc: 1);
      expect(status.total, 8);
    });

    test('serializes to and from JSON', () {
      final original = EquipmentStatus(equipmentId: 'm1151', fmc: 5, pmc: 2, nmc: 1);
      final json = original.toJson();
      final restored = EquipmentStatus.fromJson(json);
      expect(restored.equipmentId, 'm1151');
      expect(restored.fmc, 5);
      expect(restored.pmc, 2);
      expect(restored.nmc, 1);
    });

    test('isEmpty returns true when all counts are zero', () {
      expect(EquipmentStatus(equipmentId: 'x').isEmpty, isTrue);
      expect(EquipmentStatus(equipmentId: 'x', fmc: 1).isEmpty, isFalse);
    });
  });

  group('SavedReport', () {
    test('serializes to and from JSON', () {
      final report = SavedReport(
        unitName: '1-12 IN A Co',
        siteName: 'Main CP',
        items: [
          EquipmentStatus(equipmentId: 'm1151', fmc: 5, pmc: 2, nmc: 1),
        ],
        timestamp: DateTime.utc(2026, 4, 1, 14, 30),
        recipientNames: ['SGT Miller', 'CPT Jones'],
      );
      final json = jsonEncode(report.toJson());
      final restored = SavedReport.fromJson(jsonDecode(json));
      expect(restored.unitName, '1-12 IN A Co');
      expect(restored.siteName, 'Main CP');
      expect(restored.items, hasLength(1));
      expect(restored.items.first.fmc, 5);
      expect(restored.recipientNames, ['SGT Miller', 'CPT Jones']);
      expect(restored.timestamp.year, 2026);
    });
  });
}
