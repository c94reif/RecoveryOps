import 'package:circle_x/domain/usecases/identity/parse_cac_barcode.dart';

String? findDodId(Iterable<String> lines) {
  String? labelledDodId;
  String? unlabelledDodId;

  for (final rawLine in lines) {
    final line = rawLine.replaceAllMapped(
      RegExp(r'(\d)[  ](?=\d)'),
      (match) => match.group(1)!,
    );

    for (final match in RegExp(r'(?<!\d)(\d{10})(?!\d)').allMatches(line)) {
      final digits = match.group(1)!;
      final value = int.parse(digits);
      if (value < ParseCacBarcode.lowestEdipi ||
          value > ParseCacBarcode.highestEdipi) {
        continue;
      }
      if (_mentionsId(line)) {
        labelledDodId ??= digits;
      } else {
        unlabelledDodId ??= digits;
      }
    }
  }

  return labelledDodId ?? unlabelledDodId;
}

bool _mentionsId(String line) {
  final upper = line.toUpperCase();
  return RegExp(r'\bID\b').hasMatch(upper) || upper.contains('DOD');
}
