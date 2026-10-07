import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/mileage_reading.dart';
import 'package:circle_x/domain/usecases/vehicle/find_mileage_readings.dart';

void main() {
  List<String> read(List<String> lines) =>
      findMileageReadings(lines).map((reading) => reading.display).toList();

  test('reads odometers with leading zeros, grouping and tenths', () {
    expect(read(['ODO 001234.5 mi', 'ODOMETER: 12,345', '123 456.7 KM']),
        ['1234.5 mi', '12345 mi', '123456.7 km']);
  });

  test('handles odometer labels and units on separate OCR lines', () {
    expect(read(['ODO', '42.1', 'KM']), ['42.1 km']);
    expect(read(['TOTAL DISTANCE: 0 MILES']), ['0 mi']);
  });

  test('never combines gauge values or interprets labels as mileage', () {
    expect(
        read([
          '20',
          '40',
          '60',
          'MPH',
          'RPM 2000',
          'TRIP A 1234.5',
          'HOURS 5678',
          '24 V',
          '60 PSI',
          'ODO ERROR',
          '12 34',
          '-12345',
          '12345/67890',
          '1.2.3',
          '12,34',
          '12345678',
          'I2345'
        ]),
        isEmpty);
  });

  test('rejects separate trip and hour labels on either side of the value', () {
    expect(read(['TRIP A', '1234.5', 'HOURS', '5678']), isEmpty);
    expect(read(['5678', 'HOURS']), isEmpty);
    expect(read(['ODO 12345', '24']), ['12345 mi']);
  });

  test('keeps multiple candidates distinct and removes duplicate readings', () {
    expect(read(['ODO 12345', '12345', '54321 km']), ['12345 mi', '54321 km']);
  });

  test('manual entry accepts zero, commas and one decimal without OCR guesses',
      () {
    expect(MileageReading.parse('0', MileageUnit.miles)?.display, '0 mi');
    expect(MileageReading.parse(' 12,345.6 ', MileageUnit.kilometers)?.display,
        '12345.6 km');
    for (final invalid in [
      '',
      '-1',
      'NaN',
      'Infinity',
      '1e5',
      '12,34',
      '123.45',
      '123 mi',
      '12O45',
      '10000000'
    ]) {
      expect(MileageReading.parse(invalid, MileageUnit.miles), isNull,
          reason: invalid);
    }
  });

  test('received readings reject invalid values and units', () {
    for (final value in [-1, double.infinity, double.nan, 10000000]) {
      expect(
          () =>
              MileageReading(value: value.toDouble(), unit: MileageUnit.miles),
          throwsFormatException);
    }
    for (final map in <Map<String, Object?>>[
      {'value': '12345', 'unit': 'mi'},
      {'value': 12345, 'unit': 'hours'},
      {},
    ]) {
      expect(() => MileageReading.fromMap(map), throwsFormatException);
    }
  });
}
