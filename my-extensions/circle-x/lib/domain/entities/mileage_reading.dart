enum MileageUnit {
  miles('mi', 'Miles'),
  kilometers('km', 'Kilometers');

  final String symbol;
  final String label;
  const MileageUnit(this.symbol, this.label);
}

/// An operator-confirmed odometer value, in the units shown on the dashboard.
class MileageReading {
  final double value;
  final MileageUnit unit;

  MileageReading({required this.value, required this.unit}) {
    if (!value.isFinite || value < 0 || value > 9999999.9) {
      throw const FormatException('Invalid mileage');
    }
  }

  String get number => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
  String get display => '$number ${unit.symbol}';

  static MileageReading? parse(String text, MileageUnit unit) {
    final trimmed = text.trim();
    if (!RegExp(r'^(?:\d{1,7}|\d{1,3}(?:,\d{3}){1,2})(?:\.\d)?$')
        .hasMatch(trimmed)) {
      return null;
    }
    final value = double.tryParse(trimmed.replaceAll(',', ''));
    if (value == null || value > 9999999.9) return null;
    return MileageReading(value: value, unit: unit);
  }

  Map<String, Object> toMap() => {'value': value, 'unit': unit.symbol};

  static MileageReading fromMap(Map<String, Object?> map) {
    final value = map['value'];
    final unit = MileageUnit.values
        .where((unit) => unit.symbol == map['unit'])
        .firstOrNull;
    if (value is! num || unit == null) {
      throw const FormatException('Invalid mileage');
    }
    return MileageReading(value: value.toDouble(), unit: unit);
  }
}
