import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/identity/find_dod_id.dart';

/// Recorded shapes of what ML Kit hands back off the back of a CAC — one
/// string per recognised line, labels and values often on the same line.
void main() {
  group('the number on the back of the card', () {
    test('is picked out of the full set of printed numbers', () {
      final lines = [
        'GENEVA CONVENTIONS IDENTIFICATION CARD',
        'DoD ID Number 1087987498',
        'DoD Benefits Number 10879874981',
        'Date of Birth 1990JAN15',
        'Blood Type O POS',
      ];

      expect(findDodId(lines), '1087987498');
    });

    test('is never the eleven-digit benefits number, even alone', () {
      // Its first nine digits are the same Soldier; its length is not.
      expect(findDodId(['DoD Benefits Number 10879874981']), isNull);
    });

    test('is never an eight-digit date of birth', () {
      expect(findDodId(['Date of Birth 19900115']), isNull);
    });

    test('survives the overlay splitting the digits with a space', () {
      expect(findDodId(['DoD ID Number 10879 87498']), '1087987498');
    });

    test(
        'is not assembled across a letter — the benefits number stays '
        'separate', () {
      // "1087987498" followed on the same line by a label and more digits.
      expect(findDodId(['ID 1087987498 DBN 10879874981']), '1087987498');
    });

    test('prefers the labelled line when two ten-digit runs are seen', () {
      final lines = [
        '2001234567',
        'DoD ID Number 1087987498',
      ];

      expect(findDodId(lines), '1087987498');
    });

    test('takes an unlabelled run when the label did not read', () {
      expect(findDodId(['1087987498']), '1087987498');
    });

    test('ignores ten digits DEERS has never issued', () {
      expect(findDodId(['DoD ID Number 0000000001']), isNull);
    });

    test('finds nothing on an empty frame', () {
      expect(findDodId(const []), isNull);
      expect(findDodId(['', 'ARMY']), isNull);
    });
  });
}
