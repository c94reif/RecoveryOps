import 'package:le_sdk/le_sdk.dart';

class EquipmentItem {
  final String id;
  final String name;
  final String nsn;

  const EquipmentItem({required this.id, required this.name, required this.nsn});

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
        id: json['id'] as String,
        name: json['name'] as String,
        nsn: json['nsn'] as String,
      );
}

class EquipmentCategory {
  final String name;
  final List<EquipmentItem> items;

  const EquipmentCategory({required this.name, required this.items});

  factory EquipmentCategory.fromJson(Map<String, dynamic> json) =>
      EquipmentCategory(
        name: json['name'] as String,
        items: (json['items'] as List)
            .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class UnitInfo {
  final String name;
  final String uic;
  final String? color;
  final String? parentUic;
  final List<UnitInfo> subunits;

  const UnitInfo({
    required this.name,
    required this.uic,
    this.color,
    this.parentUic,
    this.subunits = const [],
  });

  factory UnitInfo.fromJson(Map<String, dynamic> json, {String? parentUic}) =>
      UnitInfo(
        name: json['name'] as String,
        uic: json['uic'] as String,
        color: json['color'] as String?,
        parentUic: parentUic,
        subunits: (json['subunits'] as List?)
                ?.map((e) => UnitInfo.fromJson(
                      e as Map<String, dynamic>,
                      parentUic: json['uic'] as String,
                    ))
                .toList() ??
            [],
      );
}

class SiteInfo {
  final String id;
  final String name;
  final String unitUic;
  final LatLng center;
  final List<LatLng> boundary;

  const SiteInfo({
    required this.id,
    required this.name,
    required this.unitUic,
    required this.center,
    required this.boundary,
  });

  factory SiteInfo.fromJson(Map<String, dynamic> json) => SiteInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        unitUic: json['unitUic'] as String,
        center: LatLng(
          (json['center']['lat'] as num).toDouble(),
          (json['center']['lng'] as num).toDouble(),
        ),
        boundary: (json['boundary'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList(),
      );
}

class EquipmentConfig {
  final List<UnitInfo> units;
  final List<SiteInfo> sites;
  final List<EquipmentCategory> categories;

  const EquipmentConfig({
    required this.units,
    required this.sites,
    required this.categories,
  });

  factory EquipmentConfig.fromJson(Map<String, dynamic> json) =>
      EquipmentConfig(
        units: (json['units'] as List)
            .map((e) => UnitInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        sites: (json['sites'] as List)
            .map((e) => SiteInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        categories: (json['categories'] as List)
            .map((e) => EquipmentCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<UnitInfo> get allUnits {
    final result = <UnitInfo>[];
    for (final unit in units) {
      result.add(unit);
      result.addAll(unit.subunits);
    }
    return result;
  }

  List<SiteInfo> sitesForUnit(UnitInfo unit) {
    final uics = <String>{unit.uic};
    if (unit.parentUic != null) {
      uics.add(unit.parentUic!);
    }
    return sites.where((s) => uics.contains(s.unitUic)).toList();
  }

  List<EquipmentItem> get allItems =>
      categories.expand((c) => c.items).toList();

  EquipmentItem? findItem(String id) {
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  List<EquipmentItem> searchItems(String query) {
    final q = query.toLowerCase();
    return allItems
        .where((item) =>
            item.name.toLowerCase().contains(q) ||
            item.nsn.toLowerCase().contains(q))
        .toList();
  }
}
