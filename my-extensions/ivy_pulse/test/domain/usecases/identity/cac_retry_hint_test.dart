import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/identity/cac_retry_hint.dart';

void main() {
  group('what the operator is told, and when', () {
    test('nothing before a scan has been tried', () {
      expect(cacRetryHint(0), isNull);
    });

    test('nothing on the first miss', () {
      // The rejection carries its own instruction — wipe the card, move
      // closer, turn it over. Stacking a second piece of advice on top of it
      // while the Soldier is still lining the card up is how someone in the
      // rain stops reading the panel at all.
      expect(cacRetryHint(1), isNull);
    });

    test('the second miss offers the rotation, which is the non-obvious one',
        () {
      // The PDF417's bars run the long way up a portrait card, so a card held
      // upright puts a tall thin symbol in a wide frame and most of the sensor
      // is spent on card stock and sky.
      final hint = cacRetryHint(2);

      expect(hint, isNotNull);
      expect(hint, contains('fill the box'));
      expect(hint, contains('across the frame'));
    });

    test('the third miss moves on to glare, which framing cannot fix', () {
      final hint = cacRetryHint(3);

      expect(hint, isNotNull);
      expect(hint, contains('shadow'));
      expect(hint, isNot(contains('fill the box')),
          reason: 'repeating advice that has already failed twice reads as '
              'the app not listening');
    });

    test('the advice stops escalating rather than running out', () {
      // A Soldier on their ninth attempt still gets the best thing there is to
      // say, not null and not something new invented to fill the space.
      expect(cacRetryHint(4), cacRetryHint(3));
      expect(cacRetryHint(9), cacRetryHint(3));
      expect(cacRetryHint(99), cacRetryHint(3));
    });

    test('a negative count cannot crash the refused card', () {
      // Not reachable through the view model, which only ever increments —
      // but this is a pure function on a plain int and the refused card has no
      // business being the place that finds out.
      expect(cacRetryHint(-1), isNull);
    });

    test(
        'both hints are instructions the Soldier can carry out standing '
        'there', () {
      for (final hint in [cacRetryHint(2)!, cacRetryHint(3)!]) {
        expect(hint, endsWith('.'));
        // Nothing that needs equipment they do not have in their hands.
        expect(hint.toLowerCase(), isNot(contains('lighting')));
        expect(hint.toLowerCase(), isNot(contains('scanner')));
      }
    });
  });
}
