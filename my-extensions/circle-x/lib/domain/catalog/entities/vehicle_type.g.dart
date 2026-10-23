// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/tm_source/catalog-manifest.mjs
// Regenerate with ./tool/generate_catalog.sh.

enum VehicleType {
  stryker(
    wireName: 'STRYKER',
    displayName: 'Stryker',
    family: 'Stryker',
    variant: 'Family PMCS',
    technicalManual: 'TM 9-2355-311-10',
  ),
  jltv(
    wireName: 'JLTV',
    displayName: 'JLTV',
    family: 'JLTV',
    variant: 'Family PMCS',
    technicalManual: 'TM 9-2320-400-10',
  );

  final String wireName;
  final String displayName;
  final String family;
  final String variant;
  final String technicalManual;

  const VehicleType({
    required this.wireName,
    required this.displayName,
    required this.family,
    required this.variant,
    required this.technicalManual,
  });

  static VehicleType fromWireName(String value) =>
      tryFromWireName(value) ??
      (throw ArgumentError('Unknown vehicle type: $value'));

  static VehicleType? tryFromWireName(String? value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}
