import 'package:circle_x/domain/entities/mileage_reading.dart';

List<MileageReading> findMileageReadings(List<String> lines) {
  final readings = <String, MileageReading>{};
  final label =
      RegExp(r'^(?:ODO(?:METER)?|MILEAGE|TOTAL(?: DISTANCE)?)\s*:?\s*');
  final units = RegExp(r'\s*(KM|KILOMETERS?|MI|MILES?)$');
  final unrelated =
      RegExp(r'\b(?:TRIP|RPM|MPH|KM/H|KPH|HRS?|HOURS?|VOLTS?|PSI|FUEL|TEMP)\b');
  for (var i = 0; i < lines.length; i++) {
    var text = lines[i].trim().toUpperCase();
    if (unrelated.hasMatch(text)) continue;
    final previous = i == 0 ? '' : lines[i - 1].trim().toUpperCase();
    if (unrelated.hasMatch(previous) &&
        !RegExp(r'\d').hasMatch(previous) &&
        !label.hasMatch(text)) {
      continue;
    }
    final labeled = label.hasMatch(text) ||
        (label.hasMatch(previous) && previous.replaceFirst(label, '').isEmpty);
    text = text.replaceFirst(label, '');
    final match = units.firstMatch(text);
    final next = i + 1 < lines.length ? lines[i + 1].trim().toUpperCase() : '';
    if (!labeled &&
        match == null &&
        unrelated.hasMatch(next) &&
        !RegExp(r'\d').hasMatch(next)) {
      continue;
    }
    final unitText = match?.group(1) ??
        (RegExp(r'^(?:KM|KILOMETERS?|MI|MILES?)$').hasMatch(next) ? next : '');
    final unit =
        unitText.startsWith('K') ? MileageUnit.kilometers : MileageUnit.miles;
    text = text.replaceFirst(units, '').trim();
    if (RegExp(r'^\d{1,3}(?: \d{3}){1,2}(?:\.\d)?$').hasMatch(text)) {
      text = text.replaceAll(' ', ',');
    }
    final reading = MileageReading.parse(text, unit);
    if (reading == null) continue;
    final digits = text.split('.').first.replaceAll(',', '').length;
    if (!labeled && unitText.isEmpty && digits < 4) continue;
    readings[reading.display] = reading;
  }
  return readings.values.toList();
}
