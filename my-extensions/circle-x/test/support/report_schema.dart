import 'dart:io';

import 'package:json_schema/json_schema.dart';

final reportSchema = JsonSchema.create(
  File('schemas/report-v1.schema.json').readAsStringSync(),
);

void validateReportRecord(Map<String, Object?> data) {
  final result = reportSchema.validate(data, validateFormats: true);
  if (!result.isValid) {
    throw FormatException('Invalid mesh record: ${result.errors}');
  }
}
