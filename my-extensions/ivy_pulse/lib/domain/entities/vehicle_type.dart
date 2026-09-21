/// Vehicle platforms this extension carries a TM PMCS catalog for.
///
/// Adding a platform means adding a value here plus registering its catalog
/// with the catalog source — no existing check logic changes.
enum VehicleType {
  stryker,
  jltv;

  String get wireName => switch (this) {
        VehicleType.stryker => 'STRYKER',
        VehicleType.jltv => 'JLTV',
      };

  String get displayName => switch (this) {
        VehicleType.stryker => 'Stryker',
        VehicleType.jltv => 'JLTV',
      };

  /// Technical manual the catalog was transcribed from, shown on the setup
  /// screen so the operator can confirm they are on the right checklist.
  String get technicalManual => switch (this) {
        VehicleType.stryker => 'TM 9-2355-311-10',
        VehicleType.jltv => 'TM 9-2320-400-10',
      };

  static VehicleType fromWireName(String value) => switch (value) {
        'STRYKER' => VehicleType.stryker,
        'JLTV' => VehicleType.jltv,
        _ => throw ArgumentError('Unknown vehicle type: $value'),
      };

  static VehicleType? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final type in VehicleType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}
