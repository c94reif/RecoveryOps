import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_storage_codec.dart';

import '../support/fakes.dart';

void main() {
  for (final field in ['severity', 'phase']) {
    test('stored invalid $field cannot become an empty fault list', () {
      final faults = [buildFault().toMap()..[field] = 'UNKNOWN'];
      expect(
        () => PmcsStorageCodec.decodeFaults('report-1', jsonEncode(faults)),
        throwsFormatException,
      );
    });
  }

  test('valid empty and populated fault lists still round trip', () {
    expect(PmcsStorageCodec.decodeFaults('report-1', '[]'), isEmpty);
    final original = buildFault();
    final restored = PmcsStorageCodec.decodeFaults(
      'report-1',
      PmcsStorageCodec.encodeFaults([original]),
    ).single;
    expect(restored.toMap(), original.toMap());
    expect(restored.sessionId, 'report-1');
  });
}
