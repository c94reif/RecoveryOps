import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/catalog/jltv_pmcs_catalog.g.dart';
import 'package:circle_x/data/catalog/stryker_pmcs_catalog.g.dart';
import 'package:circle_x/data/services/static_pmcs_catalog_source.dart';
import 'package:circle_x/domain/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

void main() {
  group('catalog integrity', () {
    // Counts pinned against the TM transcriptions the generator reads. A
    // change here means the source data moved — regenerate deliberately, do
    // not just update the number.
    test('the Stryker catalog carries every TM check', () {
      expect(strykerPmcsCatalog.itemCountFor(PmcsPhase.before), 44);
      expect(strykerPmcsCatalog.itemCountFor(PmcsPhase.during), 15);
      expect(strykerPmcsCatalog.itemCountFor(PmcsPhase.after), 19);
      expect(strykerPmcsCatalog.totalItemCount, 78);
    });

    test('the JLTV catalog carries every TM check', () {
      expect(jltvPmcsCatalog.itemCountFor(PmcsPhase.before), 55);
      expect(jltvPmcsCatalog.itemCountFor(PmcsPhase.during), 8);
      expect(jltvPmcsCatalog.itemCountFor(PmcsPhase.after), 31);
      expect(jltvPmcsCatalog.totalItemCount, 94);
    });

    for (final entry in StaticPmcsCatalogSource.defaultCatalogs.entries) {
      final name = entry.key.displayName;
      final catalog = entry.value;

      test('$name item ids are unique', () {
        final ids = <String>{};
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            expect(ids.add(item.id), isTrue, reason: 'duplicate ${item.id}');
          }
        }
        expect(ids, hasLength(catalog.totalItemCount));
      });

      test('$name every check offers a serviceable option plus faults', () {
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            expect(item.faults.length, greaterThanOrEqualTo(2),
                reason: item.id);
            expect(item.serviceableLabel, item.faults.first);
          }
        }
      });

      test('$name no check is missing its text', () {
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            expect(item.item.trim(), isNotEmpty, reason: item.id);
            expect(item.check.trim(), isNotEmpty, reason: item.id);
            for (final fault in item.faults) {
              expect(fault.trim(), isNotEmpty, reason: item.id);
            }
          }
        }
      });

      test('$name every check resolves back to its category', () {
        for (final phase in PmcsPhase.values) {
          for (final item in catalog.itemsFor(phase)) {
            expect(catalog.findItem(item.id)?.id, item.id);
            expect(catalog.categoryNameFor(item.id), isNotNull,
                reason: item.id);
          }
        }
      });

      test('$name has no empty category', () {
        for (final phase in PmcsPhase.values) {
          for (final category in catalog.categoriesFor(phase)) {
            expect(category.items, isNotEmpty, reason: category.name);
            expect(category.itemCount, category.items.length);
          }
        }
      });

      test('$name labels resolve by index and reject out-of-range', () {
        final item = PmcsPhase.values.expand(catalog.itemsFor).first;
        expect(item.labelAt(0), item.faults.first);
        expect(item.labelAt(-1), '');
        expect(item.labelAt(item.faults.length), '');
      });
    }

    test('an unknown item id is not found', () {
      expect(strykerPmcsCatalog.findItem('NOT-A-REAL-ID'), isNull);
      expect(strykerPmcsCatalog.categoryNameFor('NOT-A-REAL-ID'), isNull);
    });
  });

  group('StaticPmcsCatalogSource', () {
    test('registers every generated vehicle and preserves its stored identity',
        () {
      final source = StaticPmcsCatalogSource();

      expect(source.supportedVehicles, VehicleType.values);
      for (final vehicle in VehicleType.values) {
        expect(source.catalogFor(vehicle).vehicleType, vehicle);
        expect(source.catalogFor(vehicle).totalItemCount, greaterThan(0));
        expect(VehicleType.fromWireName(vehicle.wireName), vehicle);
        expect(vehicle.family.trim(), isNotEmpty);
        expect(vehicle.variant.trim(), isNotEmpty);
        expect(vehicle.technicalManual.trim(), isNotEmpty);
      }
      expect(VehicleType.fromWireName('STRYKER'), VehicleType.stryker);
      expect(VehicleType.fromWireName('JLTV'), VehicleType.jltv);
      expect(VehicleType.tryFromWireName('UNKNOWN'), isNull);
      expect(VehicleType.tryFromWireName(null), isNull);
      expect(() => VehicleType.fromWireName('UNKNOWN'), throwsArgumentError);
    });

    test('a platform can be added without touching the flow', () {
      const custom = PmcsCatalog(
        vehicleType: VehicleType.stryker,
        phases: {},
      );
      final source =
          StaticPmcsCatalogSource(catalogs: {VehicleType.stryker: custom});

      expect(source.supportedVehicles, [VehicleType.stryker]);
      expect(source.catalogFor(VehicleType.stryker).totalItemCount, 0);
    });

    test('an unregistered platform fails loudly rather than silently empty',
        () {
      final source = StaticPmcsCatalogSource(
          catalogs: {VehicleType.stryker: strykerPmcsCatalog});

      expect(() => source.catalogFor(VehicleType.jltv), throwsStateError);
    });
  });
}
