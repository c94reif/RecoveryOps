import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_readiness/config.dart';

void main() {
  group('EquipmentConfig', () {
    late EquipmentConfig config;

    setUp(() {
      config = EquipmentConfig.fromJson(jsonDecode(_sampleConfig));
    });

    test('parses units with subunits', () {
      expect(config.units, hasLength(1));
      expect(config.units.first.name, '1-12 IN');
      expect(config.units.first.uic, 'WAJPAA');
      // Value comes from LatticeColorScheme.dark.accent
      expect(config.units.first.color, '#FF6B35');
      expect(config.units.first.subunits, hasLength(3));
      expect(config.units.first.subunits[0].name, '1-12 IN A Co');
      expect(config.units.first.subunits[0].uic, 'WAJPA0');
    });

    test('allUnits returns parent and subunits flattened', () {
      final all = config.allUnits;
      expect(all, hasLength(4));
      expect(all.map((u) => u.name), containsAll([
        '1-12 IN', '1-12 IN A Co', '1-12 IN B Co', '1-12 IN C Co',
      ]));
    });

    test('parses sites with boundary coordinates', () {
      expect(config.sites, hasLength(2));
      final mainCp = config.sites.first;
      expect(mainCp.id, 'main_cp');
      expect(mainCp.name, 'Main CP');
      expect(mainCp.unitUic, 'WAJPAA');
      expect(mainCp.center.latitude, 33.6937);
      expect(mainCp.center.longitude, -117.9165);
      expect(mainCp.boundary, hasLength(4));
    });

    test('sitesForUnit returns sites matching unit UIC or parent UIC', () {
      final parentSites = config.sitesForUnit(config.units.first);
      expect(parentSites.map((s) => s.name), contains('Main CP'));

      final subunit = config.units.first.subunits.first;
      final subunitSites = config.sitesForUnit(subunit);
      expect(subunitSites.map((s) => s.name), contains('Main CP'));
    });

    test('parses equipment categories with items', () {
      expect(config.categories, hasLength(3));
      expect(config.categories[0].name, 'Wheeled Vehicles');
      expect(config.categories[0].items, hasLength(2));
      expect(config.categories[0].items[0].id, 'm1151');
      expect(config.categories[0].items[0].name, 'M1151 HMMWV');
      expect(config.categories[0].items[0].nsn, '2320-01-346-9317');
    });

    test('allItems returns all items across categories', () {
      final all = config.allItems;
      expect(all, hasLength(5));
    });

    test('findItem returns item by id', () {
      final item = config.findItem('m2a3');
      expect(item, isNotNull);
      expect(item!.name, 'M2A3 Bradley');
    });

    test('findItem returns null for unknown id', () {
      expect(config.findItem('nonexistent'), isNull);
    });

    test('searchItems filters by name and NSN', () {
      expect(config.searchItems('HMMWV'), hasLength(1));
      expect(config.searchItems('2320'), hasLength(2));
      expect(config.searchItems('bradley'), hasLength(1));
      expect(config.searchItems('zzz'), isEmpty);
    });
  });
}

const _sampleConfig = '''
{
  "units": [
    {
      "name": "1-12 IN",
      "uic": "WAJPAA",
      "color": "#FF6B35",
      "subunits": [
        { "name": "1-12 IN A Co", "uic": "WAJPA0" },
        { "name": "1-12 IN B Co", "uic": "WAJPB0" },
        { "name": "1-12 IN C Co", "uic": "WAJPC0" }
      ]
    }
  ],
  "sites": [
    {
      "id": "main_cp",
      "name": "Main CP",
      "unitUic": "WAJPAA",
      "center": { "lat": 33.6937, "lng": -117.9165 },
      "boundary": [
        { "lat": 33.6945, "lng": -117.9175 },
        { "lat": 33.6945, "lng": -117.9155 },
        { "lat": 33.6928, "lng": -117.9155 },
        { "lat": 33.6928, "lng": -117.9175 }
      ]
    },
    {
      "id": "fob_north",
      "name": "FOB North",
      "unitUic": "WAJPAA",
      "center": { "lat": 33.7050, "lng": -117.9100 },
      "boundary": [
        { "lat": 33.7060, "lng": -117.9115 },
        { "lat": 33.7060, "lng": -117.9085 },
        { "lat": 33.7040, "lng": -117.9085 },
        { "lat": 33.7040, "lng": -117.9115 }
      ]
    }
  ],
  "categories": [
    {
      "name": "Wheeled Vehicles",
      "items": [
        { "id": "m1151", "name": "M1151 HMMWV", "nsn": "2320-01-346-9317" },
        { "id": "m1083", "name": "M1083 FMTV", "nsn": "2320-01-444-1084" }
      ]
    },
    {
      "name": "Tracked Vehicles",
      "items": [
        { "id": "m2a3", "name": "M2A3 Bradley", "nsn": "2350-01-360-8762" }
      ]
    },
    {
      "name": "Weapons Systems",
      "items": [
        { "id": "m240b", "name": "M240B Machine Gun", "nsn": "1005-01-412-9683" },
        { "id": "m252", "name": "M252 81mm Mortar", "nsn": "1015-01-355-3029" }
      ]
    }
  ]
}
''';
